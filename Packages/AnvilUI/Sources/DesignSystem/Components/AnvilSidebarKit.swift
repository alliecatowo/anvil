import SwiftUI

struct AnvilSidebarSectionHeader: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil

    var body: some View {
        HStack(spacing: AnvilSpacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Text(title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            if let count {
                Text("\(count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .textCase(nil)
    }
}

struct AnvilSidebarRowButton<Trailing: View>: View {
    let title: String
    let icon: String
    var subtitle: String? = nil
    var isActive: Bool = false
    var shortcut: String? = nil
    let action: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        icon: String,
        subtitle: String? = nil,
        isActive: Bool = false,
        shortcut: String? = nil,
        action: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.isActive = isActive
        self.shortcut = shortcut
        self.action = action
        self.trailing = trailing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(isActive ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(isActive ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let shortcut {
                    Text(shortcut)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                trailing()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .frame(minHeight: AnvilSpacing.listItemHeight)
            .background(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AnvilSidebarInfoRow<Trailing: View>: View {
    let title: String
    let icon: String
    var detail: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        icon: String,
        detail: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.detail = detail
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.8))
                .frame(width: 16, alignment: .top)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(1)

                if let detail {
                    Text(detail)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(2)
                }
            }

            Spacer()
            trailing()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(minHeight: AnvilSpacing.listItemHeight, alignment: .top)
    }
}
