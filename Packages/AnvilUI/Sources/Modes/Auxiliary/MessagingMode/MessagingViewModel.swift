import SwiftUI

// MARK: - Models

struct Channel: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let isDirect: Bool
    var unreadCount: Int
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let content: String
    let timestamp: Date
    let isCurrentUser: Bool

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - ViewModel

@MainActor
class MessagingViewModel: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var directMessages: [Channel] = []
    @Published var selectedChannelId: UUID?
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""

    var selectedChannel: Channel? {
        let all = channels + directMessages
        return all.first { $0.id == selectedChannelId }
    }

    init() {
        channels = [
            Channel(name: "general", icon: "number", isDirect: false, unreadCount: 3),
            Channel(name: "engineering", icon: "number", isDirect: false, unreadCount: 0),
            Channel(name: "design-system", icon: "number", isDirect: false, unreadCount: 1),
            Channel(name: "ship-it", icon: "number", isDirect: false, unreadCount: 0),
            Channel(name: "random", icon: "number", isDirect: false, unreadCount: 7),
        ]

        directMessages = [
            Channel(name: "Sarah Kim", icon: "person.fill", isDirect: true, unreadCount: 2),
            Channel(name: "Alex Rivera", icon: "person.fill", isDirect: true, unreadCount: 0),
            Channel(name: "Jordan Lee", icon: "person.fill", isDirect: true, unreadCount: 0),
        ]

        selectedChannelId = channels.first?.id

        let now = Date()
        messages = [
            ChatMessage(
                author: "Sarah Kim",
                content: "Hey team, the new auxiliary modes are looking great! The database explorer is really useful.",
                timestamp: now.addingTimeInterval(-3600),
                isCurrentUser: false
            ),
            ChatMessage(
                author: "Alex Rivera",
                content: "Agreed! I especially like the schema tree view. Can we add index information too?",
                timestamp: now.addingTimeInterval(-3200),
                isCurrentUser: false
            ),
            ChatMessage(
                author: "You",
                content: "Good idea - I'll add index info in the next iteration. For now the constraint indicators should help.",
                timestamp: now.addingTimeInterval(-2800),
                isCurrentUser: true
            ),
            ChatMessage(
                author: "Jordan Lee",
                content: "The terminal mode tabs are slick. Any plans for split panes?",
                timestamp: now.addingTimeInterval(-1800),
                isCurrentUser: false
            ),
            ChatMessage(
                author: "Sarah Kim",
                content: "Split panes would be amazing. Also, could we get a shared terminal session feature for pairing?",
                timestamp: now.addingTimeInterval(-900),
                isCurrentUser: false
            ),
            ChatMessage(
                author: "You",
                content: "Split panes are on the roadmap. Shared sessions would need some backend work but it's a great idea.",
                timestamp: now.addingTimeInterval(-300),
                isCurrentUser: true
            ),
        ]
    }

    // MARK: - Actions

    func selectChannel(_ id: UUID) {
        selectedChannelId = id

        // Clear unread count
        if let index = channels.firstIndex(where: { $0.id == id }) {
            channels[index].unreadCount = 0
        } else if let index = directMessages.firstIndex(where: { $0.id == id }) {
            directMessages[index].unreadCount = 0
        }
    }

    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let message = ChatMessage(
            author: "You",
            content: inputText,
            timestamp: Date(),
            isCurrentUser: true
        )
        messages.append(message)
        inputText = ""
    }
}
