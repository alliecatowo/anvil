import Foundation
import AnvilDomain

public struct FileOpenedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "editor"
    public let filePath: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, filePath: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.filePath = filePath
    }
}

public struct FileSavedEvent: AnvilDomainEvent {
    public let eventId: String
    public let timestamp: Date
    public let sourcePrimitive: String = "editor"
    public let filePath: String

    public init(eventId: String = UUID().uuidString, timestamp: Date = .now, filePath: String) {
        self.eventId = eventId
        self.timestamp = timestamp
        self.filePath = filePath
    }
}
