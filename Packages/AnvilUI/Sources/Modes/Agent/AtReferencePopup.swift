import SwiftUI
import AnvilDomain

struct AtReference: Identifiable {
    let id: String
    let label: String
    let prefix: String
    let icon: String
    let description: String

    static let categories: [AtReference] = [
        AtReference(id: "file", label: "file", prefix: "@file:", icon: "doc.text", description: "Reference a file by path"),
        AtReference(id: "ticket", label: "ticket", prefix: "@ticket:", icon: "ticket", description: "Reference a Jira ticket"),
        AtReference(id: "branch", label: "branch", prefix: "@branch:", icon: "arrow.triangle.branch", description: "Reference a Git branch"),
    ]

    /// Fuzzy match: all query characters appear in order within the label or description.
    static func fuzzyMatch(_ text: String, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        let haystack = text.lowercased()
        var idx = haystack.startIndex
        for ch in query.lowercased() {
            guard let found = haystack[idx...].firstIndex(of: ch) else { return false }
            idx = haystack.index(after: found)
        }
        return true
    }
}

/// A concrete item within a category (a file path, branch name, or ticket ID).
struct AtReferenceItem: Identifiable {
    let id: String
    let label: String
    let detail: String
    let icon: String
    let category: String

    /// Build a ContextAttachment from this item.
    func toAttachment() -> ContextAttachment {
        switch category {
        case "file":
            return .file(path: label)
        case "branch":
            return .branch(name: label)
        case "ticket":
            return .ticket(id: label, title: detail)
        default:
            return .file(path: label)
        }
    }
}

struct AtReferencePopup: View {
    let filter: String
    let projectFiles: [String]
    let branches: [String]
    let ticketIds: [String]
    let onSelectAttachment: (ContextAttachment) -> Void
    /// Legacy callback for text-only insertion (kept for backward compatibility).
    var onSelect: ((AtReference) -> Void)?

    @State private var selectedCategory: AtReference?
    @State private var selectedIndex: Int = 0

    init(
        filter: String,
        projectFiles: [String] = [],
        branches: [String] = [],
        ticketIds: [String] = [],
        onSelectAttachment: @escaping (ContextAttachment) -> Void
    ) {
        self.filter = filter
        self.projectFiles = projectFiles
        self.branches = branches
        self.ticketIds = ticketIds
        self.onSelectAttachment = onSelectAttachment
        self.onSelect = nil
    }

    /// Legacy initializer for backward compatibility (category-only selection).
    init(filter: String, onSelect: @escaping (AtReference) -> Void) {
        self.filter = filter
        self.projectFiles = []
        self.branches = []
        self.ticketIds = []
        self.onSelectAttachment = { _ in }
        self.onSelect = onSelect
    }

    // MARK: - Filtering

    private var query: String {
        let raw = filter.lowercased().trimmingCharacters(in: .init(charactersIn: "@"))
        // If a category is selected, strip the category prefix
        if let cat = selectedCategory {
            let catPrefix = cat.label + ":"
            if raw.hasPrefix(catPrefix) {
                return String(raw.dropFirst(catPrefix.count))
            }
        }
        return raw
    }

    private var filteredCategories: [AtReference] {
        let q = filter.lowercased().trimmingCharacters(in: .init(charactersIn: "@"))
        if q.isEmpty { return AtReference.categories }
        return AtReference.categories.filter {
            AtReference.fuzzyMatch($0.label, query: q) ||
            AtReference.fuzzyMatch($0.description, query: q)
        }
    }

    private var filteredItems: [AtReferenceItem] {
        guard let cat = selectedCategory else { return [] }
        let q = query
        switch cat.id {
        case "file":
            let items = projectFiles.map { path in
                AtReferenceItem(
                    id: "file:\(path)",
                    label: path,
                    detail: URL(fileURLWithPath: path).lastPathComponent,
                    icon: "doc.text",
                    category: "file"
                )
            }
            if q.isEmpty { return items }
            return items.filter { AtReference.fuzzyMatch($0.label, query: q) || AtReference.fuzzyMatch($0.detail, query: q) }

        case "branch":
            let items = branches.map { name in
                AtReferenceItem(
                    id: "branch:\(name)",
                    label: name,
                    detail: "",
                    icon: "arrow.triangle.branch",
                    category: "branch"
                )
            }
            if q.isEmpty { return items }
            return items.filter { AtReference.fuzzyMatch($0.label, query: q) }

        case "ticket":
            let items = ticketIds.map { tid in
                AtReferenceItem(
                    id: "ticket:\(tid)",
                    label: tid,
                    detail: "",
                    icon: "ticket",
                    category: "ticket"
                )
            }
            if q.isEmpty { return items }
            return items.filter { AtReference.fuzzyMatch($0.label, query: q) }

        default:
            return []
        }
    }

    // MARK: - Body

    var body: some View {
        if selectedCategory != nil {
            itemListView
        } else if !filteredCategories.isEmpty {
            categoryListView
        }
    }

    // MARK: - Category list (first level)

    private var categoryListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation hints header
            HStack(spacing: AnvilSpacing.sm) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                    Image(systemName: "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("navigate")
                        .font(AnvilFont.label)
                }
                HStack(spacing: 2) {
                    Image(systemName: "return")
                        .font(.system(size: 8, weight: .bold))
                    Text("select")
                        .font(AnvilFont.label)
                }
            }
            .foregroundStyle(AnvilColor.textTertiary)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, ref in
                Button {
                    selectCategory(ref)
                } label: {
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: ref.icon)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AnvilColor.accentBlue)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(ref.prefix)
                                .font(AnvilFont.code)
                                .foregroundStyle(AnvilColor.textPrimary)

                            Text(ref.description)
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(index == selectedIndex ? Color.accentColor.opacity(0.1) : .clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, AnvilSpacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
        .frame(maxWidth: 320)
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(filteredCategories.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredCategories.count {
                selectCategory(filteredCategories[selectedIndex])
            }
            return .handled
        }
        .onChange(of: filter) {
            selectedIndex = 0
        }
    }

    // MARK: - Item list (second level)

    private var itemListView: some View {
        let items = filteredItems

        return VStack(alignment: .leading, spacing: 0) {
            // Back button + category header
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    selectedCategory = nil
                    selectedIndex = 0
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)

                if let cat = selectedCategory {
                    Text(cat.prefix)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)
                }

                Spacer()

                Text("\(items.count) items")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            if items.isEmpty {
                Text("No matches")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(AnvilSpacing.md)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(items.prefix(50).enumerated()), id: \.element.id) { index, item in
                            Button {
                                onSelectAttachment(item.toAttachment())
                            } label: {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: item.icon)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(AnvilColor.accentBlue)
                                        .frame(width: 16)

                                    Text(item.detail.isEmpty ? item.label : item.detail)
                                        .font(AnvilFont.code)
                                        .foregroundStyle(AnvilColor.textPrimary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Spacer()
                                }
                                .padding(.horizontal, AnvilSpacing.md)
                                .padding(.vertical, AnvilSpacing.xs)
                                .background(index == selectedIndex ? Color.accentColor.opacity(0.1) : .clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding(.vertical, AnvilSpacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
        .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
        .frame(maxWidth: 320)
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            let maxIdx = min(items.count, 50) - 1
            selectedIndex = min(maxIdx, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < items.count {
                onSelectAttachment(items[selectedIndex].toAttachment())
            }
            return .handled
        }
        .onKeyPress(.escape) {
            selectedCategory = nil
            selectedIndex = 0
            return .handled
        }
        .onChange(of: filter) {
            selectedIndex = 0
        }
    }

    // MARK: - Helpers

    private func selectCategory(_ ref: AtReference) {
        // If using legacy mode (no items available), just forward the selection
        if onSelect != nil && projectFiles.isEmpty && branches.isEmpty && ticketIds.isEmpty {
            onSelect?(ref)
            return
        }
        selectedCategory = ref
        selectedIndex = 0
    }
}
