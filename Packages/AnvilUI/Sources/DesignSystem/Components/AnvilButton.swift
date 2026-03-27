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
            HStack(spacing: AnvilSpacing.xs) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(AnvilFont.body)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: AnvilColor.textPrimary
        case .destructive: .white
        case .ghost: AnvilColor.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: AnvilColor.accentBlue
        case .secondary: AnvilColor.backgroundTertiary
        case .destructive: AnvilColor.accentRed
        case .ghost: .clear
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: AnvilColor.accentBlue
        case .secondary: AnvilColor.borderMedium
        case .destructive: AnvilColor.accentRed
        case .ghost: .clear
        }
    }
}
