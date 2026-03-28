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
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        } actions: {
            ForEach(actions) { action in
                AnvilButton(action.title, icon: action.icon, style: action.style, action: action.action)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
