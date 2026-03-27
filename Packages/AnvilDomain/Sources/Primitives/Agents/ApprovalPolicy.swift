import Foundation

public struct ApprovalPolicy: Sendable, Codable {
    public let rules: [ApprovalRule]

    public init(rules: [ApprovalRule]) {
        self.rules = rules
    }

    public func requiresApproval(for toolName: String) -> Bool {
        for rule in rules {
            if rule.matches(toolName) {
                return rule.action == .ask
            }
        }
        return true // default: ask
    }
}

public struct ApprovalRule: Sendable, Codable {
    public let pattern: String
    public let action: ApprovalAction

    public init(pattern: String, action: ApprovalAction) {
        self.pattern = pattern
        self.action = action
    }

    public func matches(_ toolName: String) -> Bool {
        if pattern == "*" { return true }
        return toolName.hasPrefix(pattern) || toolName == pattern
    }
}

public enum ApprovalAction: String, Sendable, Codable {
    case autoApprove, ask, alwaysDeny
}
