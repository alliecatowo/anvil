import Foundation

public enum LinkType: String, Sendable, Codable {
    case linkedTo
    case createdFrom
    case triggeredBy
    case blocks
    case blockedBy
    case referencedIn
}

public struct InterPrimitiveLink: Sendable, Codable, Identifiable {
    public let id: String
    public let type: LinkType
    public let sourcePrimitive: String
    public let sourceEntityId: String
    public let targetPrimitive: String
    public let targetEntityId: String
    public let createdAt: Date

    public init(type: LinkType, sourcePrimitive: String, sourceEntityId: String, targetPrimitive: String, targetEntityId: String) {
        self.id = UUID().uuidString
        self.type = type
        self.sourcePrimitive = sourcePrimitive
        self.sourceEntityId = sourceEntityId
        self.targetPrimitive = targetPrimitive
        self.targetEntityId = targetEntityId
        self.createdAt = .now
    }
}
