import SwiftUI

enum AnvilSidebarTokens {
    static let containerPadding = AnvilSpacing.sm
    static let headerPadding = EdgeInsets(top: AnvilSpacing.sm, leading: AnvilSpacing.md, bottom: AnvilSpacing.sm, trailing: AnvilSpacing.md)
    static let sectionHeaderPadding = EdgeInsets(top: AnvilSpacing.xs, leading: AnvilSpacing.md, bottom: AnvilSpacing.xs, trailing: AnvilSpacing.md)
    static let rowInsets = EdgeInsets(top: AnvilSpacing.xxs, leading: AnvilSpacing.md, bottom: AnvilSpacing.xxs, trailing: AnvilSpacing.md)
    static let selectionBackground = AnvilColor.selectionBackground
}

struct AnvilSidebarSegment: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String?

    init(id: String? = nil, title: String, icon: String? = nil) {
        self.id = id ?? title
        self.title = title
        self.icon = icon
    }
}

struct AnvilSidebarHeaderRow<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.trailing = trailing
    }

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

            if let count {
                Text("\(count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .textCase(nil)
    }
}

struct AnvilSidebarSearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: AnvilSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .accessibilityLabel(placeholder)

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear \(placeholder)")
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.top, AnvilSpacing.xs)
    }
}

struct AnvilSidebarSegmentedPicker<Selection: Hashable>: View {
    let label: String
    let items: [SidebarPickerItem<Selection>]
    @Binding var selection: Selection

    struct SidebarPickerItem<ItemSelection: Hashable>: Identifiable {
        let id: ItemSelection
        let title: String
        let icon: String?
    }

    init(label: String, items: [SidebarPickerItem<Selection>], selection: Binding<Selection>) {
        self.label = label
        self.items = items
        self._selection = selection
    }

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(items) { item in
                if let icon = item.icon {
                    Label(item.title, systemImage: icon).tag(item.id)
                } else {
                    Text(item.title).tag(item.id)
                }
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel(label)
    }
}

struct AnvilSidebarSection<Content: View, Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        Section {
            content()
        } header: {
            AnvilSidebarHeaderRow(title: title, icon: icon, count: count, trailing: trailing)
        }
    }
}

struct AnvilSidebarDisclosureHeaderRow<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self._isExpanded = isExpanded
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: AnvilSpacing.xs) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Collapse \(title)" : "Expand \(title)")

            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Text(title)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            if let count {
                Text("\(count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            trailing()
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .textCase(nil)
    }
}

struct AnvilSidebarDisclosureSection<Content: View, Trailing: View>: View {
    let title: String
    var icon: String? = nil
    var count: Int? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        count: Int? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.icon = icon
        self.count = count
        self._isExpanded = isExpanded
        self.content = content
        self.trailing = trailing
    }

    var body: some View {
        Section {
            if isExpanded {
                content()
            }
        } header: {
            AnvilSidebarDisclosureHeaderRow(
                title: title,
                icon: icon,
                count: count,
                isExpanded: $isExpanded,
                trailing: trailing
            )
        }
    }
}

struct AnvilSidebarEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actions: [EmptyStateAction] = []

    var body: some View {
        AnvilEmptyState(icon: icon, title: title, message: message, actions: actions)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.lg)
    }
}
