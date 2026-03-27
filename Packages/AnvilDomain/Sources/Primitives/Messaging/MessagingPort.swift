import Foundation

public protocol MessagingPort: AnvilProviderDefinition {
    func channels() async throws -> [Channel]
    func channel(channelId: String) async throws -> Channel
    func messages(channelId: String, limit: Int) async throws -> [Message]
    func sendMessage(channelId: String, content: String, threadId: String?) async throws -> Message
    func threads(channelId: String) async throws -> [MessageThread]
    func threadMessages(threadId: String) async throws -> [Message]
    func searchMessages(query: String) async throws -> [Message]
    func setStatus(emoji: String, text: String) async throws
}
