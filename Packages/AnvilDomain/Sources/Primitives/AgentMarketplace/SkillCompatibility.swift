import Foundation

public struct SkillCompatibility: Sendable, Identifiable, Codable {
    public let id: String
    public let skillId: String
    public let isCompatible: Bool
    public let requiredVersion: String?
    public let currentVersion: String?
    public let issues: [CompatibilityIssue]

    public init(id: String = UUID().uuidString, skillId: String, isCompatible: Bool, requiredVersion: String? = nil, currentVersion: String? = nil, issues: [CompatibilityIssue] = []) {
        self.id = id
        self.skillId = skillId
        self.isCompatible = isCompatible
        self.requiredVersion = requiredVersion
        self.currentVersion = currentVersion
        self.issues = issues
    }
}

public struct CompatibilityIssue: Sendable, Codable {
    public let description: String
    public let severity: CompatibilityIssueSeverity

    public init(description: String, severity: CompatibilityIssueSeverity = .warning) {
        self.description = description
        self.severity = severity
    }
}

public enum CompatibilityIssueSeverity: String, Sendable, Codable {
    case info, warning, error
}
