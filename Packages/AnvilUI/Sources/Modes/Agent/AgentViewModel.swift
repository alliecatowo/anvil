import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel")

public enum SessionExportFormat {
    case markdown, json

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .json: "json"
        }
    }
}

@MainActor
public class AgentViewModel: ObservableObject {
    @Published public var sessions: [AgentSession] = []
    @Published public var selectedSessionId: String?
    @Published public var isLaunchSheetPresented = false
    @Published public var inputText = ""
    @Published public var selectedModelId = "claude-sonnet-4-6"
    @Published public var editSuggestions: [String: [CodeEditSuggestion]] = [:] // sessionId -> suggestions
    @Published public var contextAttachments: [ContextAttachment] = []
    @Published public var queuedMessages: [String] = []
    @Published public var toolPermissions: ToolPermissionStore = ToolPermissionStore()
    @Published public var guardrails: AgentGuardrails = AgentGuardrails()
    @Published public var pendingToolApproval: PendingToolApproval?

    /// A tool call awaiting user decision in Review/Ask mode.
    public struct PendingToolApproval: Identifiable {
        public let id = UUID().uuidString
        public let sessionId: String
        public let toolName: String
        public let arguments: String
        public let guardrailViolation: String?
    }

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

    public func exportSessionJSON(_ sessionId: String) -> Data? {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(session)
    }

    public func exportSessionToFile(_ sessionId: String, format: SessionExportFormat) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }

        let panel = NSSavePanel()
        panel.title = "Export Session"
        panel.nameFieldStringValue = "\(session.displayName).\(format.fileExtension)"

        switch format {
        case .markdown:
            panel.allowedContentTypes = [.plainText]
        case .json:
            panel.allowedContentTypes = [.json]
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        switch format {
        case .markdown:
            let md = exportSession(sessionId)
            try? md.write(to: url, atomically: true, encoding: .utf8)
        case .json:
            if let data = exportSessionJSON(sessionId) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    public func updateSessionModel(_ sessionId: String, modelId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].model = modelId
    }

    public func setSessionBudget(_ sessionId: String, budget: Decimal?, hardStop: Bool) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].costBudget = budget
        sessions[index].hardStopOnBudget = hardStop
    }

    // MARK: - Context Attachments

    public func addAttachment(_ attachment: ContextAttachment) {
        // Avoid duplicates
        guard !contextAttachments.contains(where: { $0.id == attachment.id }) else { return }
        contextAttachments.append(attachment)
    }

    public func removeAttachment(id: String) {
        contextAttachments.removeAll { $0.id == id }
    }

    public func clearAttachments() {
        contextAttachments.removeAll()
    }

    /// Builds context prefix from attachments to prepend to user messages.
    private func buildContextPrefix() -> String {
        guard !contextAttachments.isEmpty else { return "" }
        var parts = ["[Context]"]
        for attachment in contextAttachments {
            parts.append(attachment.contextString)
        }
        parts.append("[/Context]\n\n")
        return parts.joined(separator: "\n")
    }

    // MARK: - Inline Edit Suggestions

    public func suggestionsForCurrentSession() -> [CodeEditSuggestion] {
        guard let sessionId = selectedSessionId else { return [] }
        return editSuggestions[sessionId] ?? []
    }

    public func addEditSuggestion(_ suggestion: CodeEditSuggestion) {
        guard let sessionId = selectedSessionId else { return }
        editSuggestions[sessionId, default: []].append(suggestion)
    }

    public func acceptHunk(suggestionId: String, hunkId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }),
              let hunkIdx = suggestions[sugIdx].hunks.firstIndex(where: { $0.id == hunkId }) else { return }
        suggestions[sugIdx].hunks[hunkIdx].state = .accepted
        editSuggestions[sessionId] = suggestions
    }

    public func rejectHunk(suggestionId: String, hunkId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }),
              let hunkIdx = suggestions[sugIdx].hunks.firstIndex(where: { $0.id == hunkId }) else { return }
        suggestions[sugIdx].hunks[hunkIdx].state = .rejected
        editSuggestions[sessionId] = suggestions
    }

    public func acceptAllHunks(suggestionId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }) else { return }
        for i in suggestions[sugIdx].hunks.indices {
            suggestions[sugIdx].hunks[i].state = .accepted
        }
        editSuggestions[sessionId] = suggestions
    }

    public func rejectAllHunks(suggestionId: String) {
        guard let sessionId = selectedSessionId else { return }
        guard var suggestions = editSuggestions[sessionId],
              let sugIdx = suggestions.firstIndex(where: { $0.id == suggestionId }) else { return }
        for i in suggestions[sugIdx].hunks.indices {
            suggestions[sugIdx].hunks[i].state = .rejected
        }
        editSuggestions[sessionId] = suggestions
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

        // If the session is currently running, queue the message for later
        if let session = sessions.first(where: { $0.id == sessionId }), session.status == .running {
            queuedMessages.append(inputText)
            inputText = ""
            return
        }

        // Update model if changed
        updateSessionModel(sessionId, modelId: selectedModelId)

        // Add user message to the session (with context prefix if attachments exist)
        let contextPrefix = buildContextPrefix()
        let fullContent = contextPrefix + inputText
        let userMessage = AgentMessage(role: .user, content: fullContent)
        if let index = sessions.firstIndex(where: { $0.id == sessionId }) {
            sessions[index].messages.append(userMessage)
        }
        inputText = ""
        clearAttachments()

        // Create assistant message placeholder and mark session as running
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

            // Build ACP messages from the session history (with session memory if available)
            let acpMessages = buildACPMessages(sessionId: sessionId, projectPath: container.currentProjectPath)

            let stream = provider.complete(messages: acpMessages, model: model, tools: [], stream: true)

            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: delta)
                case .usage(let usage):
                    updateTokenUsage(sessionId: sessionId, usage: usage, model: model, appState: appState)
                    if shouldHardStop(sessionId: sessionId) {
                        updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "\n\n**Budget exceeded** — session stopped.")
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

            // Auto-name the session after its first completed exchange
            autoNameSessionIfNeeded(sessionId: sessionId)

            // Drain queued messages — send the next one if any are waiting
            drainQueuedMessage(container: container, appState: appState)

        } catch {
            updateMessageContent(sessionId: sessionId, messageId: assistantMessageId, appendText: "\n\nError: \(error.localizedDescription)")
            setSessionStatus(sessionId: sessionId, status: .failed)
            clearAgentActivity(appState: appState, status: "Failed")
        }
    }

    // MARK: - Helpers

    private func buildACPMessages(sessionId: String, projectPath: String? = nil) -> [ACPMessage] {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return [] }

        var result: [ACPMessage] = []

        // Prepend session memory as system context if available
        if let memory = loadSessionMemory(projectPath: projectPath) {
            result.append(ACPMessage(role: .system, content: "Project memory (from .anvil/memory.md):\n\n\(memory)"))
        }

        result += session.messages.compactMap { msg in
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

        return result
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

    private func clearAgentActivity(appState: AppState, status: String) {
        appState.agentStatus = status
        appState.agentCurrentTool = nil
        appState.agentActiveSessionId = nil
        appState.agentRunStartedAt = nil
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

    /// Returns true if the session has exceeded its budget and hard stop is enabled.
    func shouldHardStop(sessionId: String) -> Bool {
        guard let session = sessions.first(where: { $0.id == sessionId }),
              session.hardStopOnBudget,
              let usage = session.budgetUsage else { return false }
        return usage >= 1.0
    }

    // MARK: - Agent View Mode

    public enum AgentViewMode: Equatable {
        case conversation
        case dashboard
        case synthesisRoom(String) // room ID
    }

    @Published public var viewMode: AgentViewMode = .conversation
    @Published public var synthesisRooms: [SynthesisRoom] = []
    @Published public var sessionLinks: [SessionLink] = []
    @Published public var dashboardSelectedSessionIds: Set<String> = []

    public func showDashboard() {
        viewMode = .dashboard
        dashboardSelectedSessionIds = []
    }

    public func showConversation() {
        viewMode = .conversation
    }

    public func showSynthesisRoom(_ roomId: String) {
        viewMode = .synthesisRoom(roomId)
    }

    // MARK: - Synthesis Rooms

    public func createSynthesisRoom(sessionIds: [String], title: String? = nil) -> SynthesisRoom {
        let sessionNames = sessionIds.compactMap { id in
            sessions.first(where: { $0.id == id })?.displayName
        }
        let roomTitle = title ?? "Synthesis: \(sessionNames.prefix(2).joined(separator: " + "))"

        let room = SynthesisRoom(
            title: roomTitle,
            inputSessionIds: sessionIds,
            synthesisModel: selectedModelId
        )
        synthesisRooms.append(room)
        viewMode = .synthesisRoom(room.id)
        logger.info("Created synthesis room \(room.id) with \(sessionIds.count) sessions")
        return room
    }

    public func deleteSynthesisRoom(_ roomId: String) {
        synthesisRooms.removeAll { $0.id == roomId }
        if case .synthesisRoom(let id) = viewMode, id == roomId {
            viewMode = .dashboard
        }
    }

    public func runSynthesis(roomId: String, container: DependencyContainer, appState: AppState) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].status = .running
        synthesisRooms[index].output = ""

        // Gather context from all input sessions
        let inputSessions = synthesisRooms[index].inputSessionIds.compactMap { id in
            sessions.first(where: { $0.id == id })
        }

        var synthesisPrompt = "You are synthesizing the work of multiple AI agent sessions. Analyze their outputs, find common themes, conflicts, and produce a unified summary with actionable next steps.\n\n"

        for (i, session) in inputSessions.enumerated() {
            synthesisPrompt += "--- SESSION \(i + 1): \(session.displayName) ---\n"
            synthesisPrompt += "Model: \(session.model) | Status: \(session.status.rawValue)\n"
            synthesisPrompt += "Tokens: \(session.tokenUsage.totalTokens) | Cost: $\(NSDecimalNumber(decimal: session.cost).doubleValue)\n\n"
            for message in session.messages.suffix(10) {
                let role = message.role == .user ? "User" : "Agent"
                synthesisPrompt += "[\(role)] \(message.content.prefix(2000))\n\n"
            }
            synthesisPrompt += "\n"
        }

        synthesisPrompt += "--- SYNTHESIS TASK ---\nProvide:\n1. Key findings across all sessions\n2. Conflicts or contradictions between sessions\n3. Recommended next steps\n4. A unified summary"

        Task {
            await streamSynthesis(
                roomId: roomId,
                prompt: synthesisPrompt,
                container: container,
                appState: appState
            )
        }
    }

    private func streamSynthesis(
        roomId: String,
        prompt: String,
        container: DependencyContainer,
        appState: AppState
    ) async {
        let client = await container.getOrCreateACPClient()

        guard let provider = await client.provider() else {
            updateSynthesisOutput(roomId: roomId, text: "No ACP provider configured.")
            setSynthesisStatus(roomId: roomId, status: .failed)
            return
        }

        do {
            let models = try await provider.availableModels()
            guard let model = models.first else {
                updateSynthesisOutput(roomId: roomId, text: "No models available.")
                setSynthesisStatus(roomId: roomId, status: .failed)
                return
            }

            let messages = [ACPMessage(role: .user, content: prompt)]
            let stream = provider.complete(messages: messages, model: model, tools: [], stream: true)

            for try await event in stream {
                switch event {
                case .textDelta(let delta):
                    updateSynthesisOutput(roomId: roomId, text: delta)
                default:
                    break
                }
            }

            setSynthesisStatus(roomId: roomId, status: .completed)
        } catch {
            updateSynthesisOutput(roomId: roomId, text: "\n\nError: \(error.localizedDescription)")
            setSynthesisStatus(roomId: roomId, status: .failed)
        }
    }

    private func updateSynthesisOutput(roomId: String, text: String) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].output = (synthesisRooms[index].output ?? "") + text
    }

    private func setSynthesisStatus(roomId: String, status: SynthesisStatus) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].status = status
    }

    // MARK: - Critique Agent (Adversarial Review)

    public func dispatchCritiqueAgent(for sessionId: String) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }

        let critiqueSession = AgentSession(
            providerId: "anthropic",
            model: "claude-opus-4-6",
            status: .idle,
            workItemId: session.workItemId.map { "REVIEW-\($0)" }
        )
        sessions.insert(critiqueSession, at: 0)
        selectedSessionId = critiqueSession.id

        // Build critique prompt from the source session
        var prompt = "You are a senior code reviewer performing adversarial review. Analyze the following agent session output critically. Find bugs, security issues, missed edge cases, performance problems, and design concerns.\n\n"
        prompt += "Session: \(session.displayName)\n"
        prompt += "Model: \(session.model)\n\n"

        for message in session.messages {
            let role = message.role == .user ? "User" : "Agent"
            prompt += "[\(role)] \(message.content.prefix(3000))\n\n"
        }

        prompt += "\n--- YOUR TASK ---\nProvide a thorough critique with severity ratings (critical/warning/info) for each finding."

        if let index = sessions.firstIndex(where: { $0.id == critiqueSession.id }) {
            sessions[index].messages.append(
                AgentMessage(role: .user, content: prompt)
            )
        }

        // Link the critique session to the original
        linkSessions(from: critiqueSession.id, to: sessionId, label: "critiques")

        viewMode = .conversation
        logger.info("Dispatched critique agent \(critiqueSession.id) for session \(sessionId)")
    }

    // MARK: - Session Links

    public func linkSessions(from: String, to: String, label: String = "related") {
        guard !sessionLinks.contains(where: {
            ($0.fromSessionId == from && $0.toSessionId == to) ||
            ($0.fromSessionId == to && $0.toSessionId == from)
        }) else { return }

        let link = SessionLink(fromSessionId: from, toSessionId: to, label: label)
        sessionLinks.append(link)
    }

    public func unlinkSessions(linkId: String) {
        sessionLinks.removeAll { $0.id == linkId }
    }

    public func linkedSessions(for sessionId: String) -> [(session: AgentSession, label: String)] {
        var results: [(AgentSession, String)] = []
        for link in sessionLinks {
            if link.fromSessionId == sessionId, let s = sessions.first(where: { $0.id == link.toSessionId }) {
                results.append((s, link.label))
            } else if link.toSessionId == sessionId, let s = sessions.first(where: { $0.id == link.fromSessionId }) {
                results.append((s, link.label))
            }
        }
        return results
    }

    // MARK: - Dashboard Stats

    public var totalCost: Decimal {
        sessions.reduce(0) { $0 + $1.cost }
    }

    public var totalTokens: Int {
        sessions.reduce(0) { $0 + $1.tokenUsage.totalTokens }
    }

    public var activeSessions: [AgentSession] {
        sessions.filter { $0.status == .running }
    }

    // MARK: - Queued Messages (#277)

    private func drainQueuedMessage(container: DependencyContainer, appState: AppState) {
        guard !queuedMessages.isEmpty, let sessionId = selectedSessionId,
              sessions.first(where: { $0.id == sessionId })?.status == .idle else { return }
        inputText = queuedMessages.removeFirst()
        sendMessage(container: container, appState: appState)
    }

    // MARK: - Session Memory (#299)

    /// Reads `.anvil/memory.md` from the project root, if it exists.
    public func loadSessionMemory(projectPath: String?) -> String? {
        guard let projectPath else { return nil }
        let memoryPath = (projectPath as NSString).appendingPathComponent(".anvil/memory.md")
        guard FileManager.default.fileExists(atPath: memoryPath),
              let data = FileManager.default.contents(atPath: memoryPath),
              let content = String(data: data, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return content
    }

    // MARK: - Smart Session Auto-Naming (#306)

    private func autoNameSessionIfNeeded(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let session = sessions[index]

        // Only auto-name once, and only if there's no custom name yet
        guard session.customName == nil || session.customName?.isEmpty == true else { return }

        // Need at least one user message and one assistant response
        guard let firstUser = session.messages.first(where: { $0.role == .user }),
              session.messages.contains(where: { $0.role == .assistant && !$0.content.isEmpty }) else { return }

        // Generate a short name from the first user message
        let content = firstUser.content
            .replacingOccurrences(of: "[Context]", with: "")
            .replacingOccurrences(of: "[/Context]", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Take first meaningful line, cap at 40 chars
        let firstLine = content.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? content
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)

        let name: String
        if trimmed.count <= 40 {
            name = trimmed
        } else {
            // Try to break at a word boundary
            let prefix = String(trimmed.prefix(40))
            if let lastSpace = prefix.lastIndex(of: " ") {
                name = String(prefix[prefix.startIndex..<lastSpace]) + "..."
            } else {
                name = prefix + "..."
            }
        }

        sessions[index].customName = name
        logger.info("Auto-named session \(sessionId): \(name)")
    }

    // MARK: - Autonomy Level (#283)

    public func setAutonomyLevel(_ sessionId: String, level: AutonomyLevel) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].autonomyLevel = level
        logger.info("Set autonomy level for \(sessionId): \(level.rawValue)")
    }

    /// Evaluate whether a tool call should proceed, be queued for approval, or be blocked.
    public enum ToolCallDecision {
        case allow
        case needsApproval(reason: String?)
        case blocked(reason: String)
    }

    public func evaluateToolCall(sessionId: String, toolName: String, arguments: String) -> ToolCallDecision {
        // 1. Check guardrails first — they always take precedence
        if let fileGuardrail = checkFileGuardrail(toolName: toolName, arguments: arguments) {
            if fileGuardrail.action == .block {
                return .blocked(reason: "Guardrail: \(fileGuardrail.reason)")
            }
            return .needsApproval(reason: "Guardrail warning: \(fileGuardrail.reason)")
        }

        if let cmdGuardrail = checkCommandGuardrail(toolName: toolName, arguments: arguments) {
            if cmdGuardrail.action == .block {
                return .blocked(reason: "Guardrail: \(cmdGuardrail.reason)")
            }
            return .needsApproval(reason: "Guardrail warning: \(cmdGuardrail.reason)")
        }

        // 2. Check session autonomy level
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return .needsApproval(reason: nil) }

        switch session.autonomyLevel {
        case .auto:
            return .allow
        case .review:
            // Check tool permission memory — if "always allow" is set, skip review
            if let savedDecision = toolPermissions.decision(for: toolName), savedDecision == .autoApprove {
                return .allow
            }
            return .needsApproval(reason: nil)
        case .ask:
            // Check tool permission memory
            if let savedDecision = toolPermissions.decision(for: toolName) {
                switch savedDecision {
                case .autoApprove: return .allow
                case .alwaysDeny: return .blocked(reason: "Tool '\(toolName)' is set to always deny")
                case .ask: return .needsApproval(reason: nil)
                }
            }
            return .needsApproval(reason: nil)
        }
    }

    /// Approve a pending tool call. Optionally remember the decision.
    public func approveToolCall(remember: Bool = false) {
        guard let pending = pendingToolApproval else { return }
        if remember {
            toolPermissions.setPermission(toolName: pending.toolName, action: .autoApprove)
            saveToolPermissions()
        }
        pendingToolApproval = nil
    }

    /// Reject a pending tool call. Optionally remember the decision.
    public func rejectToolCall(remember: Bool = false) {
        guard let pending = pendingToolApproval else { return }
        if remember {
            toolPermissions.setPermission(toolName: pending.toolName, action: .alwaysDeny)
            saveToolPermissions()
        }
        pendingToolApproval = nil
    }

    private func checkFileGuardrail(toolName: String, arguments: String) -> FileGuardrail? {
        // Extract file path from tool arguments for write/edit tools
        let writeTools = ["write_file", "edit_file", "create_file", "delete_file", "patch_file"]
        guard writeTools.contains(toolName) else { return nil }

        // Try to extract "path" from JSON arguments
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["path"] as? String {
            return guardrails.isFileProtected(path)
        }
        return nil
    }

    private func checkCommandGuardrail(toolName: String, arguments: String) -> CommandGuardrail? {
        let commandTools = ["run_command", "execute", "shell", "bash"]
        guard commandTools.contains(toolName) else { return nil }

        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String {
            return guardrails.isCommandBlocked(command)
        }
        return nil
    }

    // MARK: - Tool Permission Persistence (#283)

    private func toolPermissionsURL(projectPath: String?) -> URL? {
        guard let projectPath else { return nil }
        return URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".anvil/tool-permissions.json")
    }

    public func loadToolPermissions(projectPath: String?) {
        guard let url = toolPermissionsURL(projectPath: projectPath),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(ToolPermissionStore.self, from: data) else { return }
        toolPermissions = store
        logger.info("Loaded \(store.permissions.count) tool permissions from \(url.path)")
    }

    private func saveToolPermissions() {
        // Save will be called with current project path from DependencyContainer
        // For now, encode and write — the path is resolved at call time
        logger.info("Tool permissions updated: \(self.toolPermissions.permissions.count) rules")
    }

    public func saveToolPermissions(projectPath: String?) {
        guard let url = toolPermissionsURL(projectPath: projectPath) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(toolPermissions) {
            try? data.write(to: url, options: .atomic)
        }
        logger.info("Saved \(self.toolPermissions.permissions.count) tool permissions to \(url.path)")
    }

    public func resetToolPermission(toolName: String, projectPath: String?) {
        toolPermissions.permissions.removeAll { $0.toolName == toolName }
        saveToolPermissions(projectPath: projectPath)
    }

    // MARK: - Guardrails Loading (#313)

    public func loadGuardrails(projectPath: String?) {
        guard let projectPath else {
            guardrails = AgentGuardrails()
            return
        }

        let yamlPath = (projectPath as NSString).appendingPathComponent(".anvil/guardrails.yaml")
        guard FileManager.default.fileExists(atPath: yamlPath),
              let content = FileManager.default.contents(atPath: yamlPath),
              let text = String(data: content, encoding: .utf8) else {
            guardrails = AgentGuardrails()
            return
        }

        // Simple YAML-like parser for our guardrails format
        guardrails = parseGuardrails(text)
        logger.info("Loaded guardrails: \(self.guardrails.protectedFiles.count) file rules, \(self.guardrails.blockedCommands.count) command rules")
    }

    /// Parse a simple guardrails YAML format:
    /// ```
    /// protected_files:
    ///   - pattern: "migrations/*"
    ///     reason: "Never modify migrations directly"
    ///     action: block
    /// blocked_commands:
    ///   - pattern: "git push --force"
    ///     reason: "Force push is dangerous"
    ///     action: block
    /// ```
    private func parseGuardrails(_ text: String) -> AgentGuardrails {
        var files: [FileGuardrail] = []
        var commands: [CommandGuardrail] = []

        enum Section { case none, protectedFiles, blockedCommands }
        var section: Section = .none
        var currentPattern: String?
        var currentReason: String?
        var currentAction: GuardrailAction = .block

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "protected_files:" {
                section = .protectedFiles
                continue
            } else if trimmed == "blocked_commands:" {
                section = .blockedCommands
                continue
            }

            if trimmed.hasPrefix("- pattern:") {
                // Flush previous entry
                if let pattern = currentPattern {
                    let reason = currentReason ?? ""
                    switch section {
                    case .protectedFiles:
                        files.append(FileGuardrail(pattern: pattern, reason: reason, action: currentAction))
                    case .blockedCommands:
                        commands.append(CommandGuardrail(pattern: pattern, reason: reason, action: currentAction))
                    case .none: break
                    }
                }
                currentPattern = extractQuotedValue(trimmed, prefix: "- pattern:")
                currentReason = nil
                currentAction = .block
            } else if trimmed.hasPrefix("reason:") {
                currentReason = extractQuotedValue(trimmed, prefix: "reason:")
            } else if trimmed.hasPrefix("action:") {
                let val = trimmed.replacingOccurrences(of: "action:", with: "").trimmingCharacters(in: .whitespaces)
                currentAction = val == "warn" ? .warn : .block
            }
        }

        // Flush last entry
        if let pattern = currentPattern {
            let reason = currentReason ?? ""
            switch section {
            case .protectedFiles:
                files.append(FileGuardrail(pattern: pattern, reason: reason, action: currentAction))
            case .blockedCommands:
                commands.append(CommandGuardrail(pattern: pattern, reason: reason, action: currentAction))
            case .none: break
            }
        }

        return AgentGuardrails(protectedFiles: files, blockedCommands: commands)
    }

    private func extractQuotedValue(_ line: String, prefix: String) -> String {
        var value = line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
        // Strip surrounding quotes
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            value = String(value.dropFirst().dropLast())
        }
        return value
    }

    // MARK: - Agent Plan View (#354)

    /// Generate a plan from the agent's first response. Parses numbered steps from the content.
    public func generatePlan(sessionId: String, fromContent content: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        let steps = parsePlanSteps(from: content)
        guard !steps.isEmpty else { return }

        let plan = AgentPlan(
            title: sessions[index].displayName,
            steps: steps,
            status: .draft
        )
        sessions[index].plan = plan
        logger.info("Generated plan for session \(sessionId) with \(steps.count) steps")
    }

    /// Parse numbered steps from agent text. Matches patterns like "1. Do X" or "- Step one".
    private func parsePlanSteps(from content: String) -> [PlanStep] {
        var steps: [PlanStep] = []
        var order = 0

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Match "1. Title" or "1) Title" patterns
            var title: String?
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
                title = String(trimmed[range.upperBound...])
            }
            // Match "- Title" bullet patterns (but only if they look like plan steps)
            else if trimmed.hasPrefix("- ") && trimmed.count > 4 {
                title = String(trimmed.dropFirst(2))
            }

            if let stepTitle = title, !stepTitle.isEmpty {
                steps.append(PlanStep(title: stepTitle, order: order))
                order += 1
            }
        }

        return steps
    }

    /// Approve a draft plan — mark it as approved so the agent can begin execution.
    public func approvePlan(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[index].plan != nil else { return }
        sessions[index].plan?.status = .approved
        logger.info("Plan approved for session \(sessionId)")
    }

    /// Cancel a plan.
    public func cancelPlan(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[index].plan != nil else { return }
        sessions[index].plan?.status = .cancelled
    }

    /// Update a step's status.
    public func updatePlanStepStatus(sessionId: String, stepId: String, status: PlanStepStatus) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }
        sessions[sessionIndex].plan?.steps[stepIndex].status = status

        // If this step is becoming active and plan is approved, mark plan as executing
        if status == .active, sessions[sessionIndex].plan?.status == .approved {
            sessions[sessionIndex].plan?.status = .executing
        }

        // Check if all steps are complete/skipped — if so, mark plan as completed
        if let plan = sessions[sessionIndex].plan,
           plan.steps.allSatisfy({ $0.status == .completed || $0.status == .skipped }) {
            sessions[sessionIndex].plan?.status = .completed
        }
    }

    /// Skip a step.
    public func skipPlanStep(sessionId: String, stepId: String) {
        updatePlanStepStatus(sessionId: sessionId, stepId: stepId, status: .skipped)
    }

    /// Add a user annotation to a step.
    public func annotatePlanStep(sessionId: String, stepId: String, annotation: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }
        sessions[sessionIndex].plan?.steps[stepIndex].annotation = annotation.isEmpty ? nil : annotation
    }

    /// Reorder steps by moving a step to a new position.
    public func reorderPlanStep(sessionId: String, stepId: String, newOrder: Int) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }

        var steps = sessions[sessionIndex].plan!.steps
        let step = steps.remove(at: stepIndex)
        let insertAt = min(max(newOrder, 0), steps.count)
        steps.insert(step, at: insertAt)

        // Re-number order fields
        for i in steps.indices {
            steps[i].order = i
        }
        sessions[sessionIndex].plan?.steps = steps
    }

    /// Add a new step to the plan.
    public func addPlanStep(sessionId: String, title: String, afterStepId: String? = nil) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil else { return }

        let order: Int
        if let afterId = afterStepId,
           let afterIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == afterId }) {
            order = afterIndex + 1
        } else {
            order = sessions[sessionIndex].plan?.steps.count ?? 0
        }

        let step = PlanStep(title: title, order: order)
        sessions[sessionIndex].plan?.steps.insert(step, at: order)

        // Re-number
        for i in sessions[sessionIndex].plan!.steps.indices {
            sessions[sessionIndex].plan?.steps[i].order = i
        }
    }

    /// Remove a step from the plan.
    public func removePlanStep(sessionId: String, stepId: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil else { return }
        sessions[sessionIndex].plan?.steps.removeAll { $0.id == stepId }

        // Re-number
        for i in sessions[sessionIndex].plan!.steps.indices {
            sessions[sessionIndex].plan?.steps[i].order = i
        }
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
