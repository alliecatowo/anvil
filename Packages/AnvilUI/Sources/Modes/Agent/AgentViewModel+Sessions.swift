import SwiftUI
import AnvilDomain
import AnvilApplication
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel+Sessions")

extension AgentViewModel {

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
        case .markdown: panel.allowedContentTypes = [.plainText]
        case .json: panel.allowedContentTypes = [.json]
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

    public func updateSessionModel(_ sessionId: String, modelId: String, container: DependencyContainer? = nil) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].model = modelId
        if let container {
            let useCase = container.makeSwitchAgentProviderUseCase()
            let previousProvider = sessions[index].providerId
            let sid = sessions[index].id
            Task {
                do {
                    let result = try await useCase.execute(sessionId: sid, previousProviderName: previousProvider, newProviderName: modelId, model: modelId)
                    logger.info("Provider switch recorded: \(result.previousProvider) -> \(result.newProvider)")
                } catch {
                    logger.warning("Provider switch skipped: \(error.localizedDescription)")
                }
            }
        }
    }

    public func setSessionBudget(_ sessionId: String, budget: Decimal?, hardStop: Bool) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].costBudget = budget
        sessions[index].hardStopOnBudget = hardStop
    }

    public func dispatchFromTicket(ticketId: String, title: String, description: String, model: String? = nil, eventBus: EventBus? = nil) {
        let sessionModel = model ?? selectedModelId
        let session = AgentSession(providerId: "anthropic", model: sessionModel, status: .idle, workItemId: ticketId)
        sessions.insert(session, at: 0)
        selectedSessionId = session.id
        selectedModelId = sessionModel
        let bus = eventBus ?? EventBus.shared
        Task {
            await bus.publish(AnyDomainEvent(sourcePrimitive: "agents", payload: "Session \(session.id) started for ticket \(ticketId)"))
        }
        let contextPrompt = buildTicketPrompt(ticketId: ticketId, title: title, description: description)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].messages.append(AgentMessage(role: .user, content: contextPrompt))
        }
        viewMode = .conversation
        logger.info("Dispatched agent session \(session.id) for ticket \(ticketId)")
    }

    func buildTicketPrompt(ticketId: String, title: String, description: String) -> String {
        var prompt = "Implement ticket \(ticketId): \(title)"
        if !description.isEmpty { prompt += "\n\n**Description:**\n\(description)" }
        prompt += "\n\nStart by reading the relevant files and understanding the codebase, then implement the changes."
        return prompt
    }

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

    public func createSynthesisRoom(sessionIds: [String], title: String? = nil) -> SynthesisRoom {
        let sessionNames = sessionIds.compactMap { id in sessions.first(where: { $0.id == id })?.displayName }
        let roomTitle = title ?? "Synthesis: \(sessionNames.prefix(2).joined(separator: " + "))"
        let room = SynthesisRoom(title: roomTitle, inputSessionIds: sessionIds, synthesisModel: selectedModelId)
        synthesisRooms.append(room)
        viewMode = .synthesisRoom(room.id)
        logger.info("Created synthesis room \(room.id) with \(sessionIds.count) sessions")
        return room
    }

    public func deleteSynthesisRoom(_ roomId: String) {
        synthesisRooms.removeAll { $0.id == roomId }
        if case .synthesisRoom(let id) = viewMode, id == roomId { viewMode = .dashboard }
    }

    public func runSynthesis(roomId: String, container: DependencyContainer, appState: AppState) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].status = .running
        synthesisRooms[index].output = ""
        let inputSessions = synthesisRooms[index].inputSessionIds.compactMap { id in sessions.first(where: { $0.id == id }) }
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
        Task { await streamSynthesis(roomId: roomId, prompt: synthesisPrompt, container: container, appState: appState) }
    }

    func streamSynthesis(roomId: String, prompt: String, container: DependencyContainer, appState: AppState) async {
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
                case .textDelta(let delta): updateSynthesisOutput(roomId: roomId, text: delta)
                default: break
                }
            }
            setSynthesisStatus(roomId: roomId, status: .completed)
        } catch {
            updateSynthesisOutput(roomId: roomId, text: "\n\nError: \(error.localizedDescription)")
            setSynthesisStatus(roomId: roomId, status: .failed)
        }
    }

    func updateSynthesisOutput(roomId: String, text: String) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].output = (synthesisRooms[index].output ?? "") + text
    }

    func setSynthesisStatus(roomId: String, status: SynthesisStatus) {
        guard let index = synthesisRooms.firstIndex(where: { $0.id == roomId }) else { return }
        synthesisRooms[index].status = status
    }

    public func dispatchCritiqueAgent(for sessionId: String) {
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return }
        let critiqueSession = AgentSession(providerId: "anthropic", model: "claude-opus-4-6", status: .idle, workItemId: session.workItemId.map { "REVIEW-\($0)" })
        sessions.insert(critiqueSession, at: 0)
        selectedSessionId = critiqueSession.id
        var prompt = "You are a senior code reviewer performing adversarial review. Analyze the following agent session output critically. Find bugs, security issues, missed edge cases, performance problems, and design concerns.\n\n"
        prompt += "Session: \(session.displayName)\nModel: \(session.model)\n\n"
        for message in session.messages {
            let role = message.role == .user ? "User" : "Agent"
            prompt += "[\(role)] \(message.content.prefix(3000))\n\n"
        }
        prompt += "\n--- YOUR TASK ---\nProvide a thorough critique with severity ratings (critical/warning/info) for each finding."
        if let index = sessions.firstIndex(where: { $0.id == critiqueSession.id }) {
            sessions[index].messages.append(AgentMessage(role: .user, content: prompt))
        }
        linkSessions(from: critiqueSession.id, to: sessionId, label: "critiques")
        viewMode = .conversation
        logger.info("Dispatched critique agent \(critiqueSession.id) for session \(sessionId)")
    }

    public func linkSessions(from: String, to: String, label: String = "related") {
        guard !sessionLinks.contains(where: {
            ($0.fromSessionId == from && $0.toSessionId == to) || ($0.fromSessionId == to && $0.toSessionId == from)
        }) else { return }
        sessionLinks.append(SessionLink(fromSessionId: from, toSessionId: to, label: label))
    }

    public func unlinkSessions(linkId: String) {
        sessionLinks.removeAll { $0.id == linkId }
    }

    public func linkedSessions(for sessionId: String) -> [(session: AgentSession, label: String)] {
        var results: [(AgentSession, String)] = []
        for link in sessionLinks {
            if link.fromSessionId == sessionId, let s = sessions.first(where: { $0.id == link.toSessionId }) { results.append((s, link.label)) }
            else if link.toSessionId == sessionId, let s = sessions.first(where: { $0.id == link.fromSessionId }) { results.append((s, link.label)) }
        }
        return results
    }

    public var totalCost: Decimal { sessions.reduce(0) { $0 + $1.cost } }
    public var totalTokens: Int { sessions.reduce(0) { $0 + $1.tokenUsage.totalTokens } }
    public var activeSessions: [AgentSession] { sessions.filter { $0.status == .running } }

    func autoNameSessionIfNeeded(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let session = sessions[index]
        guard session.customName == nil || session.customName?.isEmpty == true else { return }
        guard let firstUser = session.messages.first(where: { $0.role == .user }),
              session.messages.contains(where: { $0.role == .assistant && !$0.content.isEmpty }) else { return }
        let content = firstUser.content.replacingOccurrences(of: "[Context]", with: "").replacingOccurrences(of: "[/Context]", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = content.components(separatedBy: .newlines).first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? content
        let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
        let name: String
        if trimmed.count <= 40 { name = trimmed }
        else {
            let prefix = String(trimmed.prefix(40))
            if let lastSpace = prefix.lastIndex(of: " ") { name = String(prefix[prefix.startIndex..<lastSpace]) + "..." }
            else { name = prefix + "..." }
        }
        sessions[index].customName = name
        logger.info("Auto-named session \(sessionId): \(name)")
    }

    public func setAutonomyLevel(_ sessionId: String, level: AutonomyLevel) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].autonomyLevel = level
        logger.info("Set autonomy level for \(sessionId): \(level.rawValue)")
    }

    public var backgroundSessions: [AgentSession] { sessions.filter { $0.isBackground } }
    public var runningBackgroundSessions: [AgentSession] { sessions.filter { $0.isBackground && $0.status == .running } }

    public func sendToBackground(_ sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].isBackground = true
        if selectedSessionId == sessionId {
            if let next = sessions.first(where: { !$0.isBackground && $0.id != sessionId }) { selectedSessionId = next.id }
            else { viewMode = .dashboard }
        }
        logger.info("Session \(sessionId) sent to background")
    }

    public func bringToForeground(_ sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        sessions[index].isBackground = false
        selectedSessionId = sessionId
        viewMode = .conversation
        logger.info("Session \(sessionId) brought to foreground")
    }

    public func startBackgroundSession(prompt: String, model: String, container: DependencyContainer, appState: AppState) {
        let session = AgentSession(providerId: "anthropic", model: model, status: .idle, isBackground: true)
        sessions.insert(session, at: 0)
        let userMessage = AgentMessage(role: .user, content: prompt)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) { sessions[index].messages.append(userMessage) }
        let assistantMessage = AgentMessage(role: .assistant, content: "")
        let assistantId = assistantMessage.id
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].messages.append(assistantMessage)
            sessions[index].status = .running
        }
        Task {
            await streamResponse(sessionId: session.id, assistantMessageId: assistantId, container: container, appState: appState)
            await notifyBackgroundSessionCompleted(sessionId: session.id, appState: appState)
        }
        logger.info("Started background session \(session.id)")
    }

    func notifyBackgroundSessionCompleted(sessionId: String, appState: AppState) async {
        guard let session = sessions.first(where: { $0.id == sessionId }), session.isBackground else { return }
        let statusText: String
        switch session.status {
        case .idle, .completed: statusText = "completed"
        case .failed: statusText = "failed"
        case .paused: statusText = "paused (budget)"
        default: return
        }
        let content = UNMutableNotificationContent()
        content.title = "Agent Session \(statusText.capitalized)"
        content.body = "\(session.displayName) has \(statusText)."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "bg-session-\(sessionId)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        logger.info("Background session \(sessionId) \(statusText)")
    }

    public func generatePlan(sessionId: String, fromContent content: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }
        let steps = parsePlanSteps(from: content)
        guard !steps.isEmpty else { return }
        let plan = AgentPlan(title: sessions[index].displayName, steps: steps, status: .draft)
        sessions[index].plan = plan
        logger.info("Generated plan for session \(sessionId) with \(steps.count) steps")
    }

    func parsePlanSteps(from content: String) -> [PlanStep] {
        var steps: [PlanStep] = []
        var order = 0
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            var title: String?
            if let range = trimmed.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) { title = String(trimmed[range.upperBound...]) }
            else if trimmed.hasPrefix("- ") && trimmed.count > 4 { title = String(trimmed.dropFirst(2)) }
            if let stepTitle = title, !stepTitle.isEmpty {
                steps.append(PlanStep(title: stepTitle, order: order))
                order += 1
            }
        }
        return steps
    }

    public func approvePlan(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }), sessions[index].plan != nil else { return }
        sessions[index].plan?.status = .approved
        logger.info("Plan approved for session \(sessionId)")
    }

    public func cancelPlan(sessionId: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }), sessions[index].plan != nil else { return }
        sessions[index].plan?.status = .cancelled
    }

    public func updatePlanStepStatus(sessionId: String, stepId: String, status: PlanStepStatus) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }
        sessions[sessionIndex].plan?.steps[stepIndex].status = status
        if status == .active, sessions[sessionIndex].plan?.status == .approved { sessions[sessionIndex].plan?.status = .executing }
        if let plan = sessions[sessionIndex].plan, plan.steps.allSatisfy({ $0.status == .completed || $0.status == .skipped }) {
            sessions[sessionIndex].plan?.status = .completed
        }
    }

    public func skipPlanStep(sessionId: String, stepId: String) {
        updatePlanStepStatus(sessionId: sessionId, stepId: stepId, status: .skipped)
    }

    public func annotatePlanStep(sessionId: String, stepId: String, annotation: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }
        sessions[sessionIndex].plan?.steps[stepIndex].annotation = annotation.isEmpty ? nil : annotation
    }

    public func reorderPlanStep(sessionId: String, stepId: String, newOrder: Int) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil,
              let stepIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == stepId }) else { return }
        var steps = sessions[sessionIndex].plan!.steps
        let step = steps.remove(at: stepIndex)
        steps.insert(step, at: min(max(newOrder, 0), steps.count))
        for i in steps.indices { steps[i].order = i }
        sessions[sessionIndex].plan?.steps = steps
    }

    public func addPlanStep(sessionId: String, title: String, afterStepId: String? = nil) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil else { return }
        let order: Int
        if let afterId = afterStepId, let afterIndex = sessions[sessionIndex].plan?.steps.firstIndex(where: { $0.id == afterId }) { order = afterIndex + 1 }
        else { order = sessions[sessionIndex].plan?.steps.count ?? 0 }
        sessions[sessionIndex].plan?.steps.insert(PlanStep(title: title, order: order), at: order)
        for i in sessions[sessionIndex].plan!.steps.indices { sessions[sessionIndex].plan?.steps[i].order = i }
    }

    public func removePlanStep(sessionId: String, stepId: String) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              sessions[sessionIndex].plan != nil else { return }
        sessions[sessionIndex].plan?.steps.removeAll { $0.id == stepId }
        for i in sessions[sessionIndex].plan!.steps.indices { sessions[sessionIndex].plan?.steps[i].order = i }
    }

    func handleSlashCommand(_ command: SlashCommand, container: DependencyContainer, appState: AppState) {
        switch command.id {
        case "review": inputText = "/review"; sendMessage(container: container, appState: appState)
        case "commit": inputText = "/commit"; sendMessage(container: container, appState: appState)
        case "test": inputText = "/test"; sendMessage(container: container, appState: appState)
        case "fix": inputText = "/fix"; sendMessage(container: container, appState: appState)
        case "explain": inputText = "/explain "
        case "refactor": inputText = "/refactor "
        case "docs": inputText = "/docs "
        case "search": inputText = "/search "
        default: inputText = command.name + " "
        }
    }

    public func loadProjectFiles(projectPath: String? = nil) -> [String] {
        let root = projectPath ?? FileManager.default.currentDirectoryPath
        return Self.listSourceFiles(at: root, maxDepth: 3)
    }

    public func loadBranches(projectPath: String? = nil) -> [String] {
        let root = projectPath ?? FileManager.default.currentDirectoryPath
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["branch", "--format=%(refname:short)"]
        task.currentDirectoryURL = URL(fileURLWithPath: root)
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } catch { return [] }
    }

    static let sourceExtensions: Set<String> = [
        "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "java", "kt",
        "c", "h", "cpp", "hpp", "m", "mm", "rb", "ex", "exs", "yaml", "yml",
        "json", "toml", "md", "txt", "html", "css", "scss"
    ]

    static func listSourceFiles(at path: String, maxDepth: Int, currentDepth: Int = 0) -> [String] {
        guard currentDepth < maxDepth else { return [] }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var results: [String] = []
        for item in items {
            if item.hasPrefix(".") || item == "node_modules" || item == ".build" || item == "DerivedData" { continue }
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }
            if isDir.boolValue { results.append(contentsOf: listSourceFiles(at: full, maxDepth: maxDepth, currentDepth: currentDepth + 1)) }
            else {
                let ext = (item as NSString).pathExtension.lowercased()
                if sourceExtensions.contains(ext) { results.append(full) }
            }
            if results.count >= 500 { break }
        }
        return results
    }
}
