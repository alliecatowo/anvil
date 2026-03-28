import AnvilDomain
import Foundation

/// In-memory messaging store -- default implementation until a real backend (e.g. Slack) is wired.
public actor InMemoryMessagingService: MessagingPort {
    private var channels: [String: Channel] = [:]
    private var messages: [String: [Message]] = [:]  // channelId -> messages

    public let providerId = "in-memory-messaging"
    public let providerName = "In-Memory Messaging"

    public init() {
        let general = Channel(name: "general", topic: "General discussion", memberCount: 5, unreadCount: 2)
        let engineering = Channel(name: "engineering", topic: "Engineering updates", memberCount: 3)
        channels[general.id] = general
        channels[engineering.id] = engineering

        messages[general.id] = [
            Message(channelId: general.id, author: "system", content: "Welcome to #general"),
        ]
    }

    public func validateConnection() async throws -> Bool { true }

    public func channels() async throws -> [Channel] {
        Array(channels.values).sorted { $0.name < $1.name }
    }

    public func channel(channelId: String) async throws -> Channel {
        guard let ch = channels[channelId] else { throw MessagingServiceError.notFound }
        return ch
    }

    public func messages(channelId: String, limit: Int) async throws -> [Message] {
        let all = messages[channelId] ?? []
        return Array(all.suffix(limit))
    }

    public func sendMessage(channelId: String, content: String, threadId: String?) async throws -> Message {
        let msg = Message(channelId: channelId, threadId: threadId, author: "local-user", content: content)
        messages[channelId, default: []].append(msg)
        return msg
    }

    public func threads(channelId: String) async throws -> [MessageThread] {
        []
    }

    public func threadMessages(threadId: String) async throws -> [Message] {
        []
    }

    public func searchMessages(query: String) async throws -> [Message] {
        let lowered = query.lowercased()
        return messages.values.flatMap { $0 }.filter { $0.content.lowercased().contains(lowered) }
    }

    public func setStatus(emoji: String, text: String) async throws {
        // No-op for in-memory implementation
    }
}

public enum MessagingServiceError: Error, Sendable {
    case notFound
}
