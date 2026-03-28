import SwiftUI

public enum AnvilButtonStyle {
    case primary, secondary, destructive, ghost
}

public struct AnvilButton: View {
    let title: String
    let icon: String?
    let style: AnvilButtonStyle
    let action: () -> Void

    public init(_ title: String, icon: String? = nil, style: AnvilButtonStyle = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let icon {
                    Image(systemName: icon)
                }
            }
        }
        .modify(for: style)
    }
}

private extension View {
    @ViewBuilder
    func modify(for style: AnvilButtonStyle) -> some View {
        switch style {
        case .primary:
            self.buttonStyle(.borderedProminent)
                .controlSize(.small)
        case .secondary:
            self.buttonStyle(.bordered)
                .controlSize(.small)
        case .destructive:
            self.buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.small)
        case .ghost:
            self.buttonStyle(.plain)
        }
    }
}
