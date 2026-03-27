import Foundation

public struct DesignToken: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let category: DesignTokenCategory
    public let value: String
    public let description: String?

    public init(id: String = UUID().uuidString, name: String, category: DesignTokenCategory, value: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.category = category
        self.value = value
        self.description = description
    }
}

public enum DesignTokenCategory: String, Sendable, Codable {
    case color, typography, spacing, borderRadius, shadow, opacity
}
