import Foundation

public struct TicketRelation: Sendable, Identifiable, Codable {
    public let id: String
    public let type: TicketRelationType
    public let sourceId: String
    public let targetId: String

    public init(id: String = UUID().uuidString, type: TicketRelationType, sourceId: String, targetId: String) {
        self.id = id
        self.type = type
        self.sourceId = sourceId
        self.targetId = targetId
    }
}

public enum TicketRelationType: String, Sendable, Codable {
    case blocks, blockedBy, parent, child, duplicate, related
}
