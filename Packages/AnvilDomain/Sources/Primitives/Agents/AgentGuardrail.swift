import Foundation

/// Project-level guardrails loaded from `.anvil/guardrails.yaml`.
/// Enforced during tool calls to prevent agents from modifying protected files
/// or running dangerous commands.
public struct AgentGuardrails: Sendable, Codable {
    public var protectedFiles: [FileGuardrail]
    public var blockedCommands: [CommandGuardrail]

    public init(protectedFiles: [FileGuardrail] = [], blockedCommands: [CommandGuardrail] = []) {
        self.protectedFiles = protectedFiles
        self.blockedCommands = blockedCommands
    }

    /// Check if a file path is protected by guardrails.
    public func isFileProtected(_ path: String) -> FileGuardrail? {
        for guardrail in protectedFiles {
            if guardrail.matches(path) {
                return guardrail
            }
        }
        return nil
    }

    /// Check if a command is blocked by guardrails.
    public func isCommandBlocked(_ command: String) -> CommandGuardrail? {
        for guardrail in blockedCommands {
            if guardrail.matches(command) {
                return guardrail
            }
        }
        return nil
    }
}

public struct FileGuardrail: Sendable, Codable, Identifiable {
    public var id: String { pattern }
    public let pattern: String       // glob-like: "migrations/*", "*.lock", "config/production.yml"
    public let reason: String
    public let action: GuardrailAction

    public init(pattern: String, reason: String, action: GuardrailAction = .block) {
        self.pattern = pattern
        self.reason = reason
        self.action = action
    }

    public func matches(_ path: String) -> Bool {
        // Simple glob matching: support * wildcard and prefix matching
        if pattern.hasSuffix("/*") {
            let prefix = String(pattern.dropLast(2))
            return path.hasPrefix(prefix) || path.contains("/\(prefix)/")
        }
        if pattern.hasPrefix("*.") {
            let ext = String(pattern.dropFirst(1)) // ".lock"
            return path.hasSuffix(ext)
        }
        return path == pattern || path.hasSuffix("/\(pattern)")
    }
}

public struct CommandGuardrail: Sendable, Codable, Identifiable {
    public var id: String { pattern }
    public let pattern: String       // "git push --force", "rm -rf", "drop table"
    public let reason: String
    public let action: GuardrailAction

    public init(pattern: String, reason: String, action: GuardrailAction = .block) {
        self.pattern = pattern
        self.reason = reason
        self.action = action
    }

    public func matches(_ command: String) -> Bool {
        let lowered = command.lowercased()
        let patternLowered = pattern.lowercased()
        return lowered.contains(patternLowered)
    }
}

public enum GuardrailAction: String, Sendable, Codable {
    case block   // Hard block — tool call rejected with reason
    case warn    // Warn but allow override
}

/// Persisted tool permissions for "always allow" memory.
public struct ToolPermissionStore: Sendable, Codable {
    public var permissions: [ToolPermission]

    public init(permissions: [ToolPermission] = []) {
        self.permissions = permissions
    }

    /// Check if a tool has a saved permission decision.
    public func decision(for toolName: String) -> ApprovalAction? {
        for perm in permissions {
            if perm.matches(toolName) {
                return perm.action
            }
        }
        return nil
    }

    public mutating func setPermission(toolName: String, action: ApprovalAction) {
        // Remove existing permission for this tool
        permissions.removeAll { $0.toolName == toolName }
        permissions.append(ToolPermission(toolName: toolName, action: action))
    }
}

public struct ToolPermission: Sendable, Codable, Identifiable {
    public var id: String { toolName }
    public let toolName: String
    public let action: ApprovalAction
    public let createdAt: Date

    public init(toolName: String, action: ApprovalAction, createdAt: Date = .now) {
        self.toolName = toolName
        self.action = action
        self.createdAt = createdAt
    }

    public func matches(_ name: String) -> Bool {
        if toolName == "*" { return true }
        return name == toolName || name.hasPrefix(toolName)
    }
}
