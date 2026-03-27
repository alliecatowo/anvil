import SwiftUI
import AnvilDomain
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel")

@MainActor
public class AgentViewModel: ObservableObject {
    @Published public var sessions: [AgentSession] = []
    @Published public var selectedSessionId: String?
    @Published public var isLaunchSheetPresented = false
    @Published public var inputText = ""
    @Published public var selectedModelId = "claude-sonnet-4-6"

    public var selectedSession: AgentSession? {
        sessions.first { $0.id == selectedSessionId }
    }

    public init() {
        logger.info("AgentViewModel initialized")
    }

    public func startNewSession(prompt: String, model: String) {
        logger.info("Starting new session with model: \(model)")
        let session = AgentSession(
            providerId: "anthropic",
            model: model,
            status: .idle
        )
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        selectedModelId = model
        logger.info("Session created: \(session.id), total sessions: \(self.sessions.count)")
    }

    // MARK: - Session Management

    public func renameSession(_ sessionId: String, name: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].customName = name
    }

    public func deleteSession(_ sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        if selectedSessionId == sessionId {
            selectedSessionId = sessions.first?.id
        }
    }

    public func exportSession(_ sessionId: String) -> String {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return "" }

        var md = "# \(session.displayName)\n\n"
        md += "**Model:** \(session.model)  \n"
        md += "**Status:** \(session.status.rawValue)  \n"
        md += "**Started:** \(session.startedAt.formatted())  \n"
        md += "**Tokens:** \(session.tokenUsage.inputTokens) in / \(session.tokenUsage.outputTokens) out  \n"
        md += "**Cost:** $\(NSDecimalNumber(decimal: session.cost).doubleValue)\n\n"
        md += "---\n\n"

        for message in session.messages {
            let role = message.role == .user ? "You" : "Agent"
            md += "### \(role) — \(message.timestamp.formatted(date: .omitted, time: .shortened))\n\n"
            md += "\(message.content)\n\n"

            for toolCall in message.toolCalls {
                md += "> **Tool:** `\(toolCall.name)` (\(toolCall.status.rawValue))\n"
                if let result = toolCall.result {
                    md += "> ```\n> \(result.content.prefix(500))\n> ```\n"
                }
                md += "\n"
            }
        }

        return md
    }

    public func exportSessionToClipboard(_ sessionId: String) {
        let md = exportSession(sessionId)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
    }

    public func updateSessionModel(_ sessionId: String, modelId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].model = modelId
    }

    // MARK: - Ticket-to-Agent Pipeline

    /// Creates a new agent session pre-loaded with ticket context.
    /// Called from TicketDetailView after branch checkout.
    public func dispatchFromTicket(ticketId: String, title: String, description: String, model: String? = nil) {
        let sessionModel = model ?? selectedModelId
        let session = AgentSession(
            providerId: "anthropic",
            model: sessionModel,
            status: .idle,
            workItemId: ticketId
        )
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        selectedModelId = sessionModel

        // Pre-populate with a system context message and the ticket as the first user message
        let contextPrompt = buildTicketPrompt(ticketId: ticketId, title: title, description: description)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].messages.append(
                AgentMessage(role: .user, content: contextPrompt)
            )
        }

        logger.info("Dispatched agent session \(session.id) for ticket \(ticketId)")
    }

    private func buildTicketPrompt(ticketId: String, title: String, description: String) -> String {
        var prompt = "Implement ticket \(ticketId): \(title)"
        if !description.isEmpty {
            prompt += "\n\n**Description:**\n\(description)"
        }
        prompt += "\n\nStart by reading the relevant files and understanding the codebase, then implement the changes."
        return prompt
    }

    // MARK: - Send Message (ACP-powered)

    public func sendMessage(container: DependencyContainer, appState: AppState) {
        guard !inputText.isEmpty, let sessionId = selectedSessionId else { return }

        // Update model if changed
        updateSessionModel(sessionId, modelId: selectedModelId)

        // Add user message to the session
        let userMessage = AgentMessage(role: .user, content: inputText)
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(userMessage)
        }
        _ = inputText  // prompt text already captured in userMessage
        inputText = ""

        // Create assistant message placeholder and mark session as running
        let assistantMessage = AgentMessage(role: .assistant, content: "")
        let assistantId = assistantMessage.id
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(assistantMessage)
            sessions[index].status = .running
        }
        appState.agentStatus = "Running"

        // Stream the response asynchronously
        Task {
            await streamResponse(
                sessionId: sessionId,
                assistantMessageId: assistantId,
                container: container,
                appState: appState
            )
        }
    }

    private func streamResponse(
        sessionId: String,
        assistantMessageId: String,
        container: DependencyContainer,
        appState: AppState
    ) async {
        let client = await container.getOrCreateACPClient()

        guard let provider = await client.provider() else {
            updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "No ACP provider configured. Go to Settings -> Providers to add one.")
            setSessionStatus(sessionId: sessionId, status: .failed)
            appState.agentStatus = "Failed"
            return
        }

        do {
            let models = try await provider.availableModels()
            guard let model = models.first else {
                updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "No models available from the provider.")
                setSessionStatus(sessionId: sessionId, status: .failed)
                appState.agentStatus = "Failed"
                return
            }

            // Build ACP messages from the session history
            let acpMessages = buildACPMessages(sessionId: sessionId)

            let stream = provider.complete(messages: acpMessages, model: model, tools: [], stream: true)

            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: delta)
                case .usage(let usage):
                    updateTokenUsage(sessionId: sessionId, usage: usage, model: model, appState: appState)
                case .toolCallStart(let id, let name):
                    addToolCallToMessage(sessionId: sessionId, messageId: assistantMessageId, toolCallId: id, name: name)
                default:
                    break
                }
            }

            setSessionStatus(sessionId: sessionId, status: .idle)
            appState.agentStatus = "Idle"

        } catch {
            updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "\n\nError: \(error.localizedDescription)")
            setSessionStatus(sessionId: sessionId, status: .failed)
            appState.agentStatus = "Failed"
        }
    }

    // MARK: - Helpers

    private func buildACPMessages(sessionId: String) -> [ACPMessage] {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return [] }
        return session.messages.compactMap { msg in
            switch msg.role {
            case .user:
                return ACPMessage(role: .user, content: msg.content)
            case .assistant:
                guard !msg.content.isEmpty else { return nil }
                return ACPMessage(role: .assistant, content: msg.content)
            case .system:
                return ACPMessage(role: .system, content: msg.content)
            case .tool:
                return nil
            }
        }
    }

    private func updateMessageContent(sessionId: String, messageId: String, appendText: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }

        let existing = sessions[sessionIndex].messages[messageIndex]
        sessions[sessionIndex].messages[messageIndex] = AgentMessage(
            id: existing.id,
            role: existing.role,
            content: existing.content + appendText,
            toolCalls: existing.toolCalls,
            timestamp: existing.timestamp
        )
        sessions[sessionIndex].lastActivityAt = .now
    }

    private func addToolCallToMessage(sessionId: String, messageId: String, toolCallId: String, name: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let messageIndex = sessions[sessionIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }

        let existing = sessions[sessionIndex].messages[messageIndex]
        var toolCalls = existing.toolCalls
        toolCalls.append(ToolCall(id: toolCallId, name: name, arguments: "", status: .pending))
        sessions[sessionIndex].messages[messageIndex] = AgentMessage(
            id: existing.id,
            role: existing.role,
            content: existing.content,
            toolCalls: toolCalls,
            timestamp: existing.timestamp
        )
    }

    private func setSessionStatus(sessionId: String, status: AgentSessionStatus) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].status = status
        sessions[index].lastActivityAt = .now
    }

    private func updateTokenUsage(sessionId: String, usage: ACPUsage, model: ACPModel, appState: AppState) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        sessions[index].tokenUsage.inputTokens += usage.inputTokens
        sessions[index].tokenUsage.outputTokens += usage.outputTokens

        let cost = Decimal(usage.inputTokens) * model.inputCostPer1kTokens / 1000
                 + Decimal(usage.outputTokens) * model.outputCostPer1kTokens / 1000
        sessions[index].cost += cost

        appState.sessionCost = sessions[index].cost
        appState.todayCost += cost
    }

    // MARK: - Sample Data (for previews only)

    #if DEBUG
    static func withSampleData() -> AgentViewModel {
        let vm = AgentViewModel()

        let sampleMessages = [
            AgentMessage(role: .user, content: "Fix the authentication bug in the login flow"),
            AgentMessage(role: .assistant, content: "I'll start by examining the auth module to understand the current login flow.\n\nLet me read the relevant files...", toolCalls: [
                ToolCall(name: "read_file", arguments: "{\"path\": \"src/auth/handler.ts\"}", status: .completed, result: ToolResult(content: "// Auth handler with 142 lines...", type: .text)),
            ]),
            AgentMessage(role: .assistant, content: "I found the issue. The token validation is checking expiry against UTC but the token was issued with local time. Let me fix this."),
        ]

        let session = AgentSession(
            providerId: "anthropic",
            model: "claude-opus-4-6",
            status: .completed,
            workItemId: "ANV-42",
            tokenUsage: TokenUsage(inputTokens: 12500, outputTokens: 3200),
            cost: 0.42,
            messages: sampleMessages
        )
        vm.sessions = [session]
        vm.selectedSessionId = session.id
        return vm
    }
    #endif
}
