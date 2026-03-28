import Foundation
import AnvilDomain

/// Slack messaging adapter implementing MessagingPort using the Slack Web API.
/// Supports listing channels, fetching/sending messages, threads, and user status.
///
/// Configuration:
///   - `botToken`: Slack Bot User OAuth token (xoxb-...) (required)
public final class SlackMessagingAdapter: MessagingPort, @unchecked Sendable {
    public let providerId: String = "slack"
    public let providerName: String = "Slack"

    private let botToken: String
    private let baseURL = "https://slack.com/api"
    private let session: URLSession

    public init(botToken: String) {
        self.botToken = botToken
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(botToken)",
            "Content-Type": "application/json; charset=utf-8",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        let (data, _) = try await request("POST", path: "/auth.test")
        let json = try jsonObject(from: data)
        return json["ok"] as? Bool ?? false
    }

    // MARK: - MessagingPort

    public func channels() async throws -> [Channel] {
        // conversations.list returns both public and private channels the bot is in
        var allChannels: [Channel] = []
        var cursor: String? = nil

        repeat {
            var params = "types=public_channel,private_channel&exclude_archived=true&limit=200"
            if let cursor { params += "&cursor=\(cursor)" }

            let (data, _) = try await request("GET", path: "/conversations.list?\(params)")
            let json = try jsonObject(from: data)

            try checkSlackOK(json)

            guard let items = json["channels"] as? [[String: Any]] else { break }

            for item in items {
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { continue }

                let topic = (item["topic"] as? [String: Any])?["value"] as? String
                let isPrivate = item["is_private"] as? Bool ?? false
                let memberCount = item["num_members"] as? Int ?? 0
                let unreadCount = item["unread_count"] as? Int ?? item["unread_count_display"] as? Int ?? 0

                allChannels.append(Channel(
                    id: id,
                    name: name,
                    topic: topic?.isEmpty == true ? nil : topic,
                    isPrivate: isPrivate,
                    memberCount: memberCount,
                    unreadCount: unreadCount
                ))
            }

            let metadata = json["response_metadata"] as? [String: Any]
            cursor = metadata?["next_cursor"] as? String
            if cursor?.isEmpty == true { cursor = nil }
        } while cursor != nil

        return allChannels
    }

    public func channel(channelId: String) async throws -> Channel {
        let (data, _) = try await request("GET", path: "/conversations.info?channel=\(channelId)")
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let item = json["channel"] as? [String: Any],
              let id = item["id"] as? String,
              let name = item["name"] as? String else {
            throw SlackAdapterError.invalidResponse
        }

        let topic = (item["topic"] as? [String: Any])?["value"] as? String
        let isPrivate = item["is_private"] as? Bool ?? false
        let memberCount = item["num_members"] as? Int ?? 0
        let unreadCount = item["unread_count"] as? Int ?? item["unread_count_display"] as? Int ?? 0

        return Channel(
            id: id,
            name: name,
            topic: topic?.isEmpty == true ? nil : topic,
            isPrivate: isPrivate,
            memberCount: memberCount,
            unreadCount: unreadCount
        )
    }

    public func messages(channelId: String, limit: Int) async throws -> [Message] {
        let (data, _) = try await request("GET", path: "/conversations.history?channel=\(channelId)&limit=\(limit)")
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let items = json["messages"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            parseMessage(item, channelId: channelId)
        }
    }

    public func sendMessage(channelId: String, content: String, threadId: String?) async throws -> Message {
        var body: [String: Any] = [
            "channel": channelId,
            "text": content,
        ]
        if let threadId {
            body["thread_ts"] = threadId
        }

        let (data, _) = try await request("POST", path: "/chat.postMessage", body: body)
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let messageData = json["message"] as? [String: Any] else {
            throw SlackAdapterError.invalidResponse
        }

        let ts = messageData["ts"] as? String ?? ""
        let user = messageData["user"] as? String ?? messageData["bot_id"] as? String ?? "bot"

        return Message(
            id: ts,
            channelId: channelId,
            threadId: threadId,
            author: user,
            content: content,
            timestamp: parseSlackTimestamp(ts) ?? .now,
            isEdited: false
        )
    }

    public func threads(channelId: String) async throws -> [MessageThread] {
        // Fetch recent messages and find those with thread replies
        let (data, _) = try await request("GET", path: "/conversations.history?channel=\(channelId)&limit=100")
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let items = json["messages"] as? [[String: Any]] else { return [] }

        return items.compactMap { item -> MessageThread? in
            guard let replyCount = item["reply_count"] as? Int,
                  replyCount > 0,
                  let ts = item["ts"] as? String else {
                return nil
            }

            let participants = (item["reply_users"] as? [String]) ?? []
            let lastReply = item["latest_reply"] as? String

            return MessageThread(
                id: ts,
                channelId: channelId,
                rootMessageId: ts,
                replyCount: replyCount,
                lastReplyAt: lastReply.flatMap(parseSlackTimestamp),
                participants: participants
            )
        }
    }

    public func threadMessages(threadId: String) async throws -> [Message] {
        // We need the channelId, which should be encoded in the threadId or cached.
        // For the Slack API, conversations.replies requires both channel and ts.
        // Convention: threadId is "channelId:ts" or just "ts" if channel is implicit.
        let parts = threadId.split(separator: ":", maxSplits: 1)
        let channelId: String
        let ts: String

        if parts.count == 2 {
            channelId = String(parts[0])
            ts = String(parts[1])
        } else {
            // Fallback: try using threadId as ts and return empty if no channel context
            throw SlackAdapterError.missingChannelForThread
        }

        let (data, _) = try await request("GET", path: "/conversations.replies?channel=\(channelId)&ts=\(ts)&limit=100")
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let items = json["messages"] as? [[String: Any]] else { return [] }

        return items.compactMap { item in
            parseMessage(item, channelId: channelId)
        }
    }

    public func searchMessages(query: String) async throws -> [Message] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let (data, _) = try await request("GET", path: "/search.messages?query=\(encoded)&count=20")
        let json = try jsonObject(from: data)
        try checkSlackOK(json)

        guard let messages = json["messages"] as? [String: Any],
              let matches = messages["matches"] as? [[String: Any]] else {
            return []
        }

        return matches.compactMap { item -> Message? in
            let channelInfo = item["channel"] as? [String: Any]
            let channelId = channelInfo?["id"] as? String ?? item["channel"] as? String ?? ""

            return parseMessage(item, channelId: channelId)
        }
    }

    public func setStatus(emoji: String, text: String) async throws {
        let body: [String: Any] = [
            "profile": [
                "status_text": text,
                "status_emoji": emoji,
                "status_expiration": 0,
            ]
        ]

        let (data, _) = try await request("POST", path: "/users.profile.set", body: body)
        let json = try jsonObject(from: data)
        try checkSlackOK(json)
    }

    // MARK: - Private Helpers

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw SlackAdapterError.invalidURL(path)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw SlackAdapterError.apiError(httpResponse.statusCode, errorBody)
        }

        return (data, response)
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SlackAdapterError.invalidResponse
        }
        return json
    }

    private func checkSlackOK(_ json: [String: Any]) throws {
        if json["ok"] as? Bool != true {
            let error = json["error"] as? String ?? "unknown_error"
            throw SlackAdapterError.slackError(error)
        }
    }

    private func parseMessage(_ item: [String: Any], channelId: String) -> Message? {
        let ts = item["ts"] as? String ?? ""
        guard !ts.isEmpty else { return nil }

        let user = item["user"] as? String ?? item["username"] as? String ?? item["bot_id"] as? String ?? "unknown"
        let text = item["text"] as? String ?? ""
        let threadTs = item["thread_ts"] as? String
        let isEdited = item["edited"] != nil

        return Message(
            id: ts,
            channelId: channelId,
            threadId: threadTs != ts ? threadTs : nil,
            author: user,
            content: text,
            timestamp: parseSlackTimestamp(ts) ?? .now,
            isEdited: isEdited
        )
    }

    private func parseSlackTimestamp(_ ts: String?) -> Date? {
        guard let ts else { return nil }
        // Slack timestamps are Unix epoch with microseconds: "1234567890.123456"
        guard let interval = Double(ts) else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}

// MARK: - Errors

public enum SlackAdapterError: LocalizedError {
    case invalidURL(String)
    case apiError(Int, String)
    case invalidResponse
    case slackError(String)
    case missingChannelForThread

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path): "Invalid URL: \(path)"
        case .apiError(let code, let body): "Slack API error (\(code)): \(body)"
        case .invalidResponse: "Invalid response from Slack API"
        case .slackError(let error): "Slack error: \(error)"
        case .missingChannelForThread: "Thread ID must be in format 'channelId:ts' to fetch replies"
        }
    }
}
