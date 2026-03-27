import Foundation

public struct ReviewChecklist: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public var items: [ReviewChecklistItem]

    public init(id: String = UUID().uuidString, name: String, items: [ReviewChecklistItem]) {
        self.id = id
        self.name = name
        self.items = items
    }
}

public struct ReviewChecklistItem: Sendable, Identifiable, Codable {
    public let id: String
    public let label: String
    public var isChecked: Bool

    public init(id: String = UUID().uuidString, label: String, isChecked: Bool = false) {
        self.id = id
        self.label = label
        self.isChecked = isChecked
    }
}
