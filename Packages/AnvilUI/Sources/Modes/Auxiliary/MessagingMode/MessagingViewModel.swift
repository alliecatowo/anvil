import SwiftUI

// MARK: - Models

struct Channel: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let isDirect: Bool
    var unreadCount: Int
    let topic: String
    let memberCount: Int
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let author: String
    let avatarColor: Color
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
    @Published var inputText: String = ""

    /// Per-channel message storage
    private var channelMessages: [UUID: [ChatMessage]] = [:]

    var selectedChannel: Channel? {
        let all = channels + directMessages
        return all.first { $0.id == selectedChannelId }
    }

    var messages: [ChatMessage] {
        guard let id = selectedChannelId else { return [] }
        return channelMessages[id] ?? []
    }

    init() {
        channels = [
            Channel(name: "general", icon: "number", isDirect: false, unreadCount: 3, topic: "Company-wide announcements and discussion", memberCount: 48),
            Channel(name: "engineering", icon: "number", isDirect: false, unreadCount: 0, topic: "Engineering team discussions", memberCount: 22),
            Channel(name: "design-system", icon: "number", isDirect: false, unreadCount: 1, topic: "AnvilUI design tokens, components, patterns", memberCount: 8),
            Channel(name: "ship-it", icon: "number", isDirect: false, unreadCount: 0, topic: "Deployments, releases, and rollbacks", memberCount: 15),
            Channel(name: "random", icon: "number", isDirect: false, unreadCount: 7, topic: "Off-topic chat, memes, and water cooler talk", memberCount: 48),
        ]

        directMessages = [
            Channel(name: "Sarah Kim", icon: "person.fill", isDirect: true, unreadCount: 2, topic: "", memberCount: 2),
            Channel(name: "Alex Rivera", icon: "person.fill", isDirect: true, unreadCount: 0, topic: "", memberCount: 2),
            Channel(name: "Jordan Lee", icon: "person.fill", isDirect: true, unreadCount: 0, topic: "", memberCount: 2),
        ]

        loadDemoMessages()

        selectedChannelId = channels.first?.id
    }

    // MARK: - Demo Messages

    private func loadDemoMessages() {
        let now = Date()

        // #general
        if let generalId = channels.first(where: { $0.name == "general" })?.id {
            channelMessages[generalId] = [
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "Hey team, the new auxiliary modes are looking great! The database explorer is really useful.", timestamp: now.addingTimeInterval(-3600), isCurrentUser: false),
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Agreed! I especially like the schema tree view. Can we add index information too?", timestamp: now.addingTimeInterval(-3200), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Good idea - I'll add index info in the next iteration. For now the constraint indicators should help.", timestamp: now.addingTimeInterval(-2800), isCurrentUser: true),
                ChatMessage(author: "Marcus Chen", avatarColor: AnvilColor.accentAmber, content: "Shipped the new onboarding flow to staging. Could use some eyes on it before we push to prod.", timestamp: now.addingTimeInterval(-1200), isCurrentUser: false),
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "I'll take a look after standup.", timestamp: now.addingTimeInterval(-900), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Same - will review the onboarding PR this afternoon.", timestamp: now.addingTimeInterval(-600), isCurrentUser: true),
            ]
        }

        // #engineering
        if let engId = channels.first(where: { $0.name == "engineering" })?.id {
            channelMessages[engId] = [
                ChatMessage(author: "Jordan Lee", avatarColor: AnvilColor.accentRed, content: "FYI - I'm migrating the auth service to the new token rotation scheme. PR incoming.", timestamp: now.addingTimeInterval(-7200), isCurrentUser: false),
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Nice. Does that affect the session middleware at all?", timestamp: now.addingTimeInterval(-6800), isCurrentUser: false),
                ChatMessage(author: "Jordan Lee", avatarColor: AnvilColor.accentRed, content: "Shouldn't - the refresh endpoint stays the same, just the internal rotation changes. I'll flag it if anything surfaces.", timestamp: now.addingTimeInterval(-6500), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Let me know if you need help with the token validation tests. I wrote most of the original suite.", timestamp: now.addingTimeInterval(-5000), isCurrentUser: true),
            ]
        }

        // #design-system
        if let dsId = channels.first(where: { $0.name == "design-system" })?.id {
            channelMessages[dsId] = [
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "I've updated the spacing tokens to match the new 4px grid. Check AnvilSpacing for the changes.", timestamp: now.addingTimeInterval(-14400), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Looks great. Should we deprecate the old `padding4` and `padding8` names?", timestamp: now.addingTimeInterval(-13800), isCurrentUser: true),
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "Yes, I'll add deprecation warnings in the next PR. Using `xxs`, `xs`, `sm` etc from now on.", timestamp: now.addingTimeInterval(-13200), isCurrentUser: false),
            ]
        }

        // #ship-it
        if let shipId = channels.first(where: { $0.name == "ship-it" })?.id {
            channelMessages[shipId] = [
                ChatMessage(author: "DeployBot", avatarColor: AnvilColor.accentGreen, content: "exercise-service v2.14.0 deployed to production. All health checks passing.", timestamp: now.addingTimeInterval(-1800), isCurrentUser: false),
                ChatMessage(author: "Marcus Chen", avatarColor: AnvilColor.accentAmber, content: "Confirmed - latency metrics look normal post-deploy. Nice and clean.", timestamp: now.addingTimeInterval(-1500), isCurrentUser: false),
            ]
        }

        // #random
        if let randomId = channels.first(where: { $0.name == "random" })?.id {
            channelMessages[randomId] = [
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Anyone tried the new ramen place on 3rd? Apparently the tonkotsu is incredible.", timestamp: now.addingTimeInterval(-10800), isCurrentUser: false),
                ChatMessage(author: "Jordan Lee", avatarColor: AnvilColor.accentRed, content: "Went yesterday. Can confirm - best ramen within walking distance.", timestamp: now.addingTimeInterval(-10200), isCurrentUser: false),
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "Team lunch there Friday?", timestamp: now.addingTimeInterval(-9600), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "I'm in.", timestamp: now.addingTimeInterval(-9000), isCurrentUser: true),
                ChatMessage(author: "Marcus Chen", avatarColor: AnvilColor.accentAmber, content: "Count me in too. Also has anyone seen my AirPods case? Left it somewhere on the 4th floor.", timestamp: now.addingTimeInterval(-8400), isCurrentUser: false),
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Check the kitchen counter by the espresso machine. I saw one there earlier.", timestamp: now.addingTimeInterval(-7800), isCurrentUser: false),
                ChatMessage(author: "Marcus Chen", avatarColor: AnvilColor.accentAmber, content: "That's it! Thanks Alex, you're a lifesaver.", timestamp: now.addingTimeInterval(-7200), isCurrentUser: false),
            ]
        }

        // DMs - Sarah Kim
        if let sarahId = directMessages.first(where: { $0.name == "Sarah Kim" })?.id {
            channelMessages[sarahId] = [
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "Hey, quick question about the notification preferences view - are we using Toggle or our custom switch?", timestamp: now.addingTimeInterval(-5400), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Using the native Toggle with .switch style. Keeps it feeling macOS-native.", timestamp: now.addingTimeInterval(-5100), isCurrentUser: true),
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "Perfect. Also wanted to share some feedback from the design review - the inbox action buttons on hover are really nice.", timestamp: now.addingTimeInterval(-4800), isCurrentUser: false),
                ChatMessage(author: "Sarah Kim", avatarColor: AnvilColor.accentPurple, content: "One thing: can we make the urgency pills a bit larger? They're hard to tap.", timestamp: now.addingTimeInterval(-4500), isCurrentUser: false),
            ]
        }

        // DMs - Alex Rivera
        if let alexId = directMessages.first(where: { $0.name == "Alex Rivera" })?.id {
            channelMessages[alexId] = [
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Are you still working on the testing mode? Want to pair on the swift test output parser.", timestamp: now.addingTimeInterval(-18000), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Yes! That would be great. The regex for XCTest output is tricky.", timestamp: now.addingTimeInterval(-17500), isCurrentUser: true),
                ChatMessage(author: "Alex Rivera", avatarColor: AnvilColor.accentGreen, content: "Cool. I'll set up a shared terminal session after lunch.", timestamp: now.addingTimeInterval(-17000), isCurrentUser: false),
            ]
        }

        // DMs - Jordan Lee
        if let jordanId = directMessages.first(where: { $0.name == "Jordan Lee" })?.id {
            channelMessages[jordanId] = [
                ChatMessage(author: "Jordan Lee", avatarColor: AnvilColor.accentRed, content: "The terminal mode looks amazing. Can you walk me through the PTY setup sometime?", timestamp: now.addingTimeInterval(-86400), isCurrentUser: false),
                ChatMessage(author: "You", avatarColor: AnvilColor.accentBlue, content: "Sure thing. It's using SwiftTerm under the hood with a custom shell integration layer. Happy to do a walkthrough.", timestamp: now.addingTimeInterval(-82800), isCurrentUser: true),
            ]
        }
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
        guard let channelId = selectedChannelId else { return }

        let message = ChatMessage(
            author: "You",
            avatarColor: AnvilColor.accentBlue,
            content: inputText,
            timestamp: Date(),
            isCurrentUser: true
        )
        channelMessages[channelId, default: []].append(message)
        inputText = ""
    }
}
