import SwiftUI
import AnvilDomain
import AnvilApplication
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel+Tools")

extension AgentViewModel {

    public enum ToolCallDecision {
        case allow
        case needsApproval(reason: String?)
        case blocked(reason: String)
    }

    public func evaluateToolCall(sessionId: String, toolName: String, arguments: String) -> ToolCallDecision {
        if let fileGuardrail = checkFileGuardrail(toolName: toolName, arguments: arguments) {
            if fileGuardrail.action == .block { return .blocked(reason: "Guardrail: \(fileGuardrail.reason)") }
            return .needsApproval(reason: "Guardrail warning: \(fileGuardrail.reason)")
        }
        if let cmdGuardrail = checkCommandGuardrail(toolName: toolName, arguments: arguments) {
            if cmdGuardrail.action == .block { return .blocked(reason: "Guardrail: \(cmdGuardrail.reason)") }
            return .needsApproval(reason: "Guardrail warning: \(cmdGuardrail.reason)")
        }
        guard let session = sessions.first(where: { $0.id == sessionId }) else { return .needsApproval(reason: nil) }
        switch session.autonomyLevel {
        case .auto: return .allow
        case .review:
            if let savedDecision = toolPermissions.decision(for: toolName), savedDecision == .autoApprove { return .allow }
            return .needsApproval(reason: nil)
        case .ask:
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

    public func approveToolCall(remember: Bool = false) {
        guard let pending = pendingToolApproval else { return }
        if remember { toolPermissions.setPermission(toolName: pending.toolName, action: .autoApprove); saveToolPermissions() }
        pendingToolApproval = nil
    }

    public func rejectToolCall(remember: Bool = false) {
        guard let pending = pendingToolApproval else { return }
        if remember { toolPermissions.setPermission(toolName: pending.toolName, action: .alwaysDeny); saveToolPermissions() }
        pendingToolApproval = nil
    }

    func checkFileGuardrail(toolName: String, arguments: String) -> FileGuardrail? {
        let writeTools = ["write_file", "edit_file", "create_file", "delete_file", "patch_file"]
        guard writeTools.contains(toolName) else { return nil }
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let path = json["path"] as? String { return guardrails.isFileProtected(path) }
        return nil
    }

    func checkCommandGuardrail(toolName: String, arguments: String) -> CommandGuardrail? {
        let commandTools = ["run_command", "execute", "shell", "bash"]
        guard commandTools.contains(toolName) else { return nil }
        if let data = arguments.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let command = json["command"] as? String { return guardrails.isCommandBlocked(command) }
        return nil
    }

    func toolPermissionsURL(projectPath: String?) -> URL? {
        guard let projectPath else { return nil }
        return URL(fileURLWithPath: projectPath).appendingPathComponent(".anvil/tool-permissions.json")
    }

    public func loadToolPermissions(projectPath: String?) {
        guard let url = toolPermissionsURL(projectPath: projectPath),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(ToolPermissionStore.self, from: data) else { return }
        toolPermissions = store
        logger.info("Loaded \(store.permissions.count) tool permissions from \(url.path)")
    }

    func saveToolPermissions() {
        logger.info("Tool permissions updated: \(self.toolPermissions.permissions.count) rules")
    }

    public func saveToolPermissions(projectPath: String?) {
        guard let url = toolPermissionsURL(projectPath: projectPath) else { return }
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(toolPermissions) { try? data.write(to: url, options: .atomic) }
        logger.info("Saved \(self.toolPermissions.permissions.count) tool permissions to \(url.path)")
    }

    public func resetToolPermission(toolName: String, projectPath: String?) {
        toolPermissions.permissions.removeAll { $0.toolName == toolName }
        saveToolPermissions(projectPath: projectPath)
    }

    public func loadGuardrails(projectPath: String?) {
        guard let projectPath else { guardrails = AgentGuardrails(); return }
        let yamlPath = (projectPath as NSString).appendingPathComponent(".anvil/guardrails.yaml")
        guard FileManager.default.fileExists(atPath: yamlPath),
              let content = FileManager.default.contents(atPath: yamlPath),
              let text = String(data: content, encoding: .utf8) else { guardrails = AgentGuardrails(); return }
        guardrails = parseGuardrails(text)
        logger.info("Loaded guardrails: \(self.guardrails.protectedFiles.count) file rules, \(self.guardrails.blockedCommands.count) command rules")
    }

    func parseGuardrails(_ text: String) -> AgentGuardrails {
        var files: [FileGuardrail] = []
        var commands: [CommandGuardrail] = []
        enum Section { case none, protectedFiles, blockedCommands }
        var section: Section = .none
        var currentPattern: String?
        var currentReason: String?
        var currentAction: GuardrailAction = .block
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "protected_files:" { section = .protectedFiles; continue }
            else if trimmed == "blocked_commands:" { section = .blockedCommands; continue }
            if trimmed.hasPrefix("- pattern:") {
                if let pattern = currentPattern {
                    let reason = currentReason ?? ""
                    switch section {
                    case .protectedFiles: files.append(FileGuardrail(pattern: pattern, reason: reason, action: currentAction))
                    case .blockedCommands: commands.append(CommandGuardrail(pattern: pattern, reason: reason, action: currentAction))
                    case .none: break
                    }
                }
                currentPattern = extractQuotedValue(trimmed, prefix: "- pattern:")
                currentReason = nil
                currentAction = .block
            } else if trimmed.hasPrefix("reason:") { currentReason = extractQuotedValue(trimmed, prefix: "reason:")
            } else if trimmed.hasPrefix("action:") {
                let val = trimmed.replacingOccurrences(of: "action:", with: "").trimmingCharacters(in: .whitespaces)
                currentAction = val == "warn" ? .warn : .block
            }
        }
        if let pattern = currentPattern {
            let reason = currentReason ?? ""
            switch section {
            case .protectedFiles: files.append(FileGuardrail(pattern: pattern, reason: reason, action: currentAction))
            case .blockedCommands: commands.append(CommandGuardrail(pattern: pattern, reason: reason, action: currentAction))
            case .none: break
            }
        }
        return AgentGuardrails(protectedFiles: files, blockedCommands: commands)
    }

    func extractQuotedValue(_ line: String, prefix: String) -> String {
        var value = line.replacingOccurrences(of: prefix, with: "").trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 { value = String(value.dropFirst().dropLast()) }
        return value
    }
}
