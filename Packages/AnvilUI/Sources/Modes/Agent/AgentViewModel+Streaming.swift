import SwiftUI
import AnvilDomain
import AnvilApplication
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel+Streaming")

extension AgentViewModel {

    public func startNewSession(prompt: String, model: String, container: DependencyContainer) {
        startNewSession(prompt: prompt, model: model, eventBus: container.eventBus)
    }

    public func startNewSession(prompt: String, model: String, eventBus: EventBus? = nil) {
        logger.info("Starting new session with model: \(model)")
        let session = AgentSession(providerId: "anthropic", model: model, status: .idle)
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        selectedModelId = model
        logger.info("Session created: \(session.id), total sessions: \(self.sessions.count)")
        let bus = eventBus ?? EventBus.shared
        Task {
            await bus.publish(AnyDomainEvent(sourcePrimitive: "agents", payload: "Session \(session.id) started"))
        }
    }

    public func sendMessage(container: DependencyContainer, appState: AppState) {
        guard !inputText.isEmpty, let sessionId = selectedSessionId else { return }
        if let session = sessions.first(where: { $0.id == sessionId }), session.status == .running {
            queuedMessages.append(inputText)
            inputText = ""
            return
        }
        updateSessionModel(sessionId, modelId: selectedModelId, container: container)
        let contextPrefix = buildContextPrefix()
        let fullContent = contextPrefix + inputText
        let userMessage = AgentMessage(role: .user, content: fullContent)
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(userMessage)
        }
        inputText = ""
        clearAttachments()
        let assistantMessage = AgentMessage(role: .assistant, content: "")
        let assistantId = assistantMessage.id
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(assistantMessage)
            sessions[index].status = .running
        }
        appState.agentStatus = "Running"
        appState.agentActiveSessionId = sessionId
        appState.agentRunStartedAt = .now
        appState.agentCurrentTool = nil
        let isFirstMessage = sessions.first(where: { $0.id == sessionId })?.messages
            .filter({ $0.role == .user }).count == 1
        if isFirstMessage {
            Task { await createWorktreeForSession(sessionId: sessionId, container: container) }
        }
        Task {
            await streamResponse(sessionId: sessionId, assistantMessageId: assistantId, container: container, appState: appState)
        }
    }

    func createWorktreeForSession(sessionId: String, container: DependencyContainer) async {
        guard let gitAdapter = container.getOrCreateGitAdapter(),
              let projectPath = container.currentProjectPath else { return }
        let projectName = URL(fileURLWithPath: projectPath).lastPathComponent
        let sessionRef = sessions.first(where: { $0.id == sessionId })
        let branchName = "anvil/session/\(sessionRef?.workItemId ?? String(sessionId.prefix(8)))"
        let useCase = container.makeCreateWorktreeUseCase()
        do {
            try await useCase.execute(branch: branchName, sessionId: sessionId, projectName: projectName, provider: gitAdapter)
            logger.info("Worktree created via CreateWorktreeUseCase for session \(sessionId)")
        } catch {
            logger.info("CreateWorktreeUseCase failed, falling back to orchestrator: \(error.localizedDescription)")
            do {
                let path = try await container.worktreeOrchestrator.createForSession(
                    sessionId: sessionId, branch: branchName, projectName: projectName, provider: gitAdapter)
                logger.info("Worktree created via orchestrator for session \(sessionId) at \(path)")
            } catch {
                logger.warning("Worktree creation skipped for session \(sessionId): \(error.localizedDescription)")
            }
        }
    }

    func streamResponse(sessionId: String, assistantMessageId: String, container: DependencyContainer, appState: AppState) async {
        let client = await container.getOrCreateACPClient()
        guard let provider = await client.provider() else {
            updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "No ACP provider configured. Go to Settings -> Providers to add one.")
            setSessionStatus(sessionId: sessionId, status: .failed)
            clearAgentActivity(appState: appState, status: "Failed")
            return
        }
        do {
            let models = try await provider.availableModels()
            guard let model = models.first else {
                updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "No models available from the provider.")
                setSessionStatus(sessionId: sessionId, status: .failed)
                clearAgentActivity(appState: appState, status: "Failed")
                return
            }
            let acpMessages = buildACPMessages(sessionId: sessionId, projectPath: container.currentProjectPath)
            let stream = provider.complete(messages: acpMessages, model: model, tools: [], stream: true)
            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: delta)
                case .usage(let usage):
                    updateTokenUsage(sessionId: sessionId, usage: usage, model: model, appState: appState)
                    if shouldHardStop(sessionId: sessionId) {
                        updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "\n\n**Budget exceeded** -- session stopped.")
                        setSessionStatus(sessionId: sessionId, status: .paused)
                        clearAgentActivity(appState: appState, status: "Budget Exceeded")
                        return
                    }
                case .toolCallStart(let id, let name):
                    addToolCallToMessage(sessionId: sessionId, messageId: assistantMessageId, toolCallId: id, name: name)
                    appState.agentCurrentTool = name
                default:
                    break
                }
            }
            setSessionStatus(sessionId: sessionId, status: .idle)
            clearAgentActivity(appState: appState, status: "Idle")
            autoNameSessionIfNeeded(sessionId: sessionId)
            let completedSession = sessions.first(where: { $0.id == sessionId })
            let worktreePath = await container.worktreeOrchestrator.worktreePath(for: sessionId)
            let event = AgentCompletedEvent(
                sessionId: sessionId,
                workItemId: completedSession?.workItemId,
                branchName: worktreePath.map { URL(fileURLWithPath: $0).lastPathComponent }
            )
            await container.eventBus.publish(event)
            drainQueuedMessage(container: container, appState: appState)
        } catch {
            updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "\n\nError: \(error.localizedDescription)")
            setSessionStatus(sessionId: sessionId, status: .failed)
            clearAgentActivity(appState: appState, status: "Failed")
        }
    }

    func buildACPMessages(sessionId: String, projectPath: String? = nil) -> [ACPMessage] {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return [] }
        var result: [ACPMessage] = []
        if let memory = loadSessionMemory(projectPath: projectPath) {
            result.append(ACPMessage(role: .system, content: "Project memory (from .anvil/memory.md):\n\n\(memory)"))
        }
        result += session.messages.compactMap { msg in
            switch msg.role {
            case .user: return ACPMessage(role: .user, content: msg.content)
            case .assistant:
                guard !msg.content.isEmpty else { return nil }
                return ACPMessage(role: .assistant, content: msg.content)
            case .system: return ACPMessage(role: .system, content: msg.content)
            case .tool: return nil
            }
        }
        return result
    }

    func updateMessageContent(sessionId: String, messageId: String, appendText: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
        let existing = sessions[sessionIndex].messages[messageIndex]
        sessions[sessionIndex].messages[messageIndex] = AgentMessage(
            id: existing.id, role: existing.role, content: existing.content + appendText,
            toolCalls: existing.toolCalls, timestamp: existing.timestamp)
        sessions[sessionIndex].lastActivityAt = .now
    }

    func addToolCallToMessage(sessionId: String, messageId: String, toolCallId: String, name: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
        let existing = sessions[sessionIndex].messages[messageIndex]
        var toolCalls = existing.toolCalls
        toolCalls.append(ToolCall(id: toolCallId, name: name, arguments: "", status: .pending))
        sessions[sessionIndex].messages[messageIndex] = AgentMessage(
            id: existing.id, role: existing.role, content: existing.content,
            toolCalls: toolCalls, timestamp: existing.timestamp)
    }

    func clearAgentActivity(appState: AppState, status: String) {
        appState.agentStatus = status
        appState.agentCurrentTool = nil
        appState.agentActiveSessionId = nil
        appState.agentRunStartedAt = nil
    }

    func setSessionStatus(sessionId: String, status: AgentSessionStatus) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].status = status
        sessions[index].lastActivityAt = .now
    }

    func updateTokenUsage(sessionId: String, usage: ACPUsage, model: ACPModel, appState: AppState) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].tokenUsage.inputTokens += usage.inputTokens
        sessions[index].tokenUsage.outputTokens += usage.outputTokens
        let cost = Decimal(usage.inputTokens) * model.inputCostPer1kTokens / 1000
                 + Decimal(usage.outputTokens) * model.outputCostPer1kTokens / 1000
        sessions[index].cost += cost
        appState.sessionCost = sessions[index].cost
        appState.todayCost += cost
    }

    func shouldHardStop(sessionId: String) -> Bool {
        guard let session = sessions.first(where: { $0.id == sessionId }),
              session.hardStopOnBudget,
              let usage = session.budgetUsage else { return false }
        return usage >= 1.0
    }

    func drainQueuedMessage(container: DependencyContainer, appState: AppState) {
        guard !queuedMessages.isEmpty, let sessionId = selectedSessionId,
              sessions.first(where: { $0.id == sessionId })?.status == .idle else { return }
        inputText = queuedMessages.removeFirst()
        sendMessage(container: container, appState: appState)
    }
}
