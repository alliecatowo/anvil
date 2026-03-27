import SwiftUI

public struct ContentArea: View {
    @EnvironmentObject var appState: AppState

    public init() {}

    public var body: some View {
        ZStack {
            switch appState.currentMode {
            case .intent:
                IntentModeContent()
            case .agent:
                AgentModeContent()
            case .review:
                ReviewModeContent()
            case .ship:
                ShipModeContent()
            case .editor:
                EditorModeContent()
            case .database:
                DatabaseModeContent()
            case .terminal:
                TerminalModeContent()
            case .docs:
                DocsModeContent()
            case .messaging:
                MessagingModeContent()
            case .notifications:
                NotificationsModeContent()
            default:
                PlaceholderModeContent(mode: appState.currentMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }
}

// Placeholder views for each mode - will be replaced with real implementations
struct IntentModeContent: View {
    var body: some View {
        IntentMode()
    }
}

struct AgentModeContent: View {
    var body: some View {
        AgentMode()
    }
}

struct ReviewModeContent: View {
    var body: some View {
        ReviewMode()
    }
}

struct ShipModeContent: View {
    var body: some View {
        ShipMode()
    }
}

struct EditorModeContent: View {
    var body: some View {
        EditorMode()
    }
}

struct DatabaseModeContent: View {
    var body: some View {
        DatabaseMode()
    }
}

struct TerminalModeContent: View {
    var body: some View {
        TerminalMode()
    }
}

struct DocsModeContent: View {
    var body: some View {
        DocsMode()
    }
}

struct MessagingModeContent: View {
    var body: some View {
        MessagingMode()
    }
}

struct NotificationsModeContent: View {
    var body: some View {
        NotificationsMode()
    }
}

struct PlaceholderModeContent: View {
    let mode: AnvilMode

    var body: some View {
        ModeWelcomeView(
            icon: mode.icon,
            title: mode.rawValue,
            subtitle: "Coming soon.",
            hint: ""
        )
    }
}

struct ModeWelcomeView: View {
    let icon: String
    let title: String
    let subtitle: String
    let hint: String

    var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(title)
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text(subtitle)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            if !hint.isEmpty {
                Text(hint)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.top, AnvilSpacing.sm)
            }
        }
    }
}
