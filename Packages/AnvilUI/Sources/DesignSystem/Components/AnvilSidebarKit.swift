import SwiftUI

// MARK: - Sidebar Tab Bar (Xcode-style icon tab switcher)

/// Compact icon-only tab row for switching sidebar sections — no text labels, no segmented control.
/// Matches the Xcode navigator tab pattern: small SF Symbol buttons, active state via subtle tint background.
struct SidebarTabBar<S: Hashable & Sendable>: View {
    let sections: [S]
    let active: S
    let icon: (S) -> String
    let label: (S) -> String
    let onSelect: (S) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                Button {
                    onSelect(section)
                } label: {
                    Image(systemName: icon(section))
                        .font(.system(size: 12, weight: active == section ? .semibold : .regular))
                        .foregroundStyle(active == section ? Color.accentColor : Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            active == section
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(section))
                .accessibilityAddTraits(active == section ? [.isButton, .isSelected] : .isButton)
                .help(label(section))
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

// MARK: - Sidebar Section Header

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

    @State private var isHovered = false
    @GestureState private var isPressed = false

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
            .padding(.vertical, AnvilSpacing.sm)
            .background(
                isActive
                    ? AnvilColor.accentBlue.opacity(0.1)
                    : (isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.86), value: isPressed)
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
        .padding(.vertical, AnvilSpacing.sm)
    }
}
