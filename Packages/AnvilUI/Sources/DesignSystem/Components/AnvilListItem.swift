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

    public init(icon: String? = nil, title: String, subtitle: String? = nil, tag: String? = nil, tagColor: Color? = nil, timestamp: String? = nil, isSelected: Bool = false, isCompact: Bool = true) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.tag = tag
        self.tagColor = tagColor
        self.timestamp = timestamp
        self.isSelected = isSelected
        self.isCompact = isCompact
    }

    public var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            if isSelected {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AnvilColor.accentBlue)
                    .frame(width: 3)
            }

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AnvilColor.textSecondary)
                    .frame(width: 20)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
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
                            .foregroundStyle(AnvilColor.textSecondary)
                            .lineLimit(1)

                        Spacer()

                        if let timestamp {
                            Text(timestamp)
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: isCompact ? AnvilSpacing.listItemHeight : AnvilSpacing.richListItemHeight)
        .background(isSelected ? AnvilColor.selectionBackground : .clear)
        .contentShape(Rectangle())
    }
}
