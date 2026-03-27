import SwiftUI

// MARK: - Empty State Action

public struct EmptyStateAction: Identifiable {
    public let id = UUID()
    public let title: String
    public let icon: String?
    public let style: AnvilButtonStyle
    public let action: @MainActor @Sendable () -> Void

    public init(_ title: String, icon: String? = nil, style: AnvilButtonStyle = .primary, action: @escaping @MainActor @Sendable () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
}

// MARK: - Empty State View

public struct AnvilEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actions: [EmptyStateAction]

    public init(icon: String, title: String, message: String, actions: [EmptyStateAction] = []) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(title)
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            Text(message)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if !actions.isEmpty {
                HStack(spacing: AnvilSpacing.sm) {
                    ForEach(actions) { action in
                        AnvilButton(action.title, icon: action.icon, style: action.style, action: action.action)
                    }
                }
                .padding(.top, AnvilSpacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
