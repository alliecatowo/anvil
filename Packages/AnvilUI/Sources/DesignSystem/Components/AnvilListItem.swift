import SwiftUI

public struct AnvilListItem: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let tag: String?
    let tagColor: Color?
    let timestamp: String?
    let isSelected: Bool
    let isCompact: Bool
    let indentLevel: Int

    @State private var isHovered = false
    @GestureState private var isPressed = false

    public init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        tag: String? = nil,
        tagColor: Color? = nil,
        timestamp: String? = nil,
        isSelected: Bool = false,
        isCompact: Bool = true,
        indentLevel: Int = 0
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tag = tag
        self.tagColor = tagColor
        self.timestamp = timestamp
        self.isSelected = isSelected
        self.isCompact = isCompact
        self.indentLevel = indentLevel
    }

    public var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            if indentLevel > 0 {
                Color.clear
                    .frame(width: CGFloat(indentLevel) * 12)
                    .accessibilityHidden(true)
            }

            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AnvilColor.accentBlue)
                    .frame(width: 3)
            }

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let tag {
                        AnvilBadge(text: tag, color: tagColor ?? AnvilColor.accentBlue)
                    }
                }

                if let subtitle, !isCompact {
                    HStack {
                        Text(subtitle)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        if let timestamp {
                            Text(timestamp)
                                .font(AnvilFont.label)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: isCompact ? AnvilSpacing.listItemHeight : AnvilSpacing.richListItemHeight)
        .background(
            isSelected
                ? AnvilColor.accentBlue.opacity(0.15)
                : (isHovered ? Color.primary.opacity(0.06) : .clear)
        )
        .contentShape(Rectangle())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, pressed, _ in pressed = true }
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}
