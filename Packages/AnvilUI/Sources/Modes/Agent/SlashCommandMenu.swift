import SwiftUI
import AnvilDomain

// MARK: - Slash Command

/// The behavior of a slash command when selected.
enum SlashCommandType {
    /// Inserts a prompt template into the input field.
    case prompt(template: String, autoSend: Bool)
    /// Injects context immediately (e.g., /tab, /selection, /diff, /branch).
    case injectContext
    /// Shows a sub-picker for the user to choose an item (e.g., /file, /ticket).
    case picker(kind: ContextPickerKind)
}

enum ContextPickerKind {
    case file
    case ticket
}

struct SlashCommand: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let type: SlashCommandType

    // Backward compat helpers
    var autoSend: Bool {
        if case .prompt(_, let auto) = type { return auto }
        return false
    }

    var promptTemplate: String {
        if case .prompt(let template, _) = type { return template }
        return ""
    }

    var isContextCommand: Bool {
        switch type {
        case .prompt: return false
        case .injectContext, .picker: return true
        }
    }

    static let all: [SlashCommand] = promptCommands + contextCommands

    static let promptCommands: [SlashCommand] = [
        SlashCommand(
            id: "fix",
            name: "/fix",
            description: "Fix the bug",
            icon: "wrench",
            type: .prompt(template: "Please fix the following issue in the current file:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "explain",
            name: "/explain",
            description: "Explain this code",
            icon: "text.magnifyingglass",
            type: .prompt(template: "Please explain what this code does, step by step:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "test",
            name: "/test",
            description: "Generate tests",
            icon: "checkmark.circle",
            type: .prompt(template: "Please write comprehensive tests for the following code:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "commit",
            name: "/commit",
            description: "Write commit message",
            icon: "arrow.up.circle",
            type: .prompt(template: "Please write a conventional commit message for the current staged changes.", autoSend: true)
        ),
        SlashCommand(
            id: "pr",
            name: "/pr",
            description: "Create PR description",
            icon: "arrow.triangle.pull",
            type: .prompt(template: "Please write a pull request description for the following changes:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "review",
            name: "/review",
            description: "Review this diff",
            icon: "eyes",
            type: .prompt(template: "Please review the following code changes and provide feedback:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "doc",
            name: "/doc",
            description: "Generate documentation",
            icon: "doc.text",
            type: .prompt(template: "Please generate comprehensive documentation (docstrings/comments) for:\n\n", autoSend: false)
        ),
        SlashCommand(
            id: "refactor",
            name: "/refactor",
            description: "Refactor this code",
            icon: "arrow.triangle.2.circlepath",
            type: .prompt(template: "Please refactor the following code to improve readability, performance, and maintainability:\n\n", autoSend: false)
        ),
    ]

    static let contextCommands: [SlashCommand] = [
        SlashCommand(
            id: "ctx-file",
            name: "/file",
            description: "Attach a project file",
            icon: "doc.badge.plus",
            type: .picker(kind: .file)
        ),
        SlashCommand(
            id: "ctx-tab",
            name: "/tab",
            description: "Attach the focused editor tab",
            icon: "doc.text.fill",
            type: .injectContext
        ),
        SlashCommand(
            id: "ctx-selection",
            name: "/selection",
            description: "Attach the current editor selection",
            icon: "text.cursor",
            type: .injectContext
        ),
        SlashCommand(
            id: "ctx-diff",
            name: "/diff",
            description: "Attach the current git diff",
            icon: "plus.forwardslash.minus",
            type: .injectContext
        ),
        SlashCommand(
            id: "ctx-branch",
            name: "/branch",
            description: "Attach current branch info",
            icon: "arrow.triangle.branch",
            type: .injectContext
        ),
        SlashCommand(
            id: "ctx-ticket",
            name: "/ticket",
            description: "Attach a ticket from Plan",
            icon: "ticket",
            type: .picker(kind: .ticket)
        ),
    ]
}

// MARK: - Slash Command Menu

struct SlashCommandMenu: View {
    let filter: String
    let onSelect: (SlashCommand) -> Void

    private var filtered: [SlashCommand] {
        let query = filter.lowercased().trimmingCharacters(in: .init(charactersIn: "/"))
        if query.isEmpty { return SlashCommand.all }
        return SlashCommand.all.filter {
            $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query)
        }
    }

    @State private var selectedIndex: Int = 0

    var body: some View {
        if !filtered.isEmpty {
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
                    HStack(spacing: 2) {
                        Image(systemName: "escape")
                            .font(.system(size: 8, weight: .bold))
                        Text("dismiss")
                            .font(AnvilFont.label)
                    }
                }
                .foregroundStyle(AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Use arrow keys to navigate, return to select, escape to dismiss")

                Divider()

                // Context commands section
                let contextItems = filtered.filter(\.isContextCommand)
                if !contextItems.isEmpty {
                    Text("CONTEXT")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.top, AnvilSpacing.xs)
                        .padding(.bottom, 2)

                    ForEach(contextItems) { command in
                        let globalIndex = filtered.firstIndex(where: { $0.id == command.id }) ?? 0
                        commandRow(command: command, index: globalIndex)
                    }

                    if filtered.contains(where: { !$0.isContextCommand }) {
                        Divider()
                            .padding(.vertical, AnvilSpacing.xxs)
                    }
                }

                // Prompt commands section
                let promptItems = filtered.filter { !$0.isContextCommand }
                if !promptItems.isEmpty {
                    if !contextItems.isEmpty {
                        Text("PROMPTS")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .padding(.horizontal, AnvilSpacing.md)
                            .padding(.top, AnvilSpacing.xxs)
                            .padding(.bottom, 2)
                    }

                    ForEach(promptItems) { command in
                        let globalIndex = filtered.firstIndex(where: { $0.id == command.id }) ?? 0
                        commandRow(command: command, index: globalIndex)
                    }
                }
            }
            .padding(.vertical, AnvilSpacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
            .frame(maxWidth: 300)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(filtered.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex < filtered.count {
                    onSelect(filtered[selectedIndex])
                }
                return .handled
            }
            .onChange(of: filter) {
                selectedIndex = 0
            }
        }
    }

    private func commandRow(command: SlashCommand, index: Int) -> some View {
        Button {
            onSelect(command)
        } label: {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: command.icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(command.isContextCommand ? AnvilColor.accentTeal : AnvilColor.accentPurple)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(command.name)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)

                    Text(command.description)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Spacer()

                if command.autoSend {
                    Text("auto")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.accentGreen)
                        .accessibilityLabel("Auto-send enabled")
                }

                if command.isContextCommand {
                    Image(systemName: "paperclip")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.accentTeal)
                        .accessibilityLabel("Injects context")
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
            .background(index == selectedIndex ? Color.accentColor.opacity(0.1) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(command.name): \(command.description)")
    }
}

// MARK: - Context Slash Command File Picker

struct SlashFilePickerMenu: View {
    let files: [String]
    let filter: String
    let onSelect: (String) -> Void

    @State private var selectedIndex: Int = 0

    private var filtered: [String] {
        let query = filter.lowercased()
        if query.isEmpty { return Array(files.prefix(20)) }
        return files.filter {
            URL(fileURLWithPath: $0).lastPathComponent.lowercased().contains(query)
            || $0.lowercased().contains(query)
        }.prefix(20).map { $0 }
    }

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select a file")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { index, path in
                            Button {
                                onSelect(path)
                            } label: {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AnvilColor.accentBlue)
                                        .frame(width: 16)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(URL(fileURLWithPath: path).lastPathComponent)
                                            .font(AnvilFont.sidebarItem)
                                            .foregroundStyle(AnvilColor.textPrimary)
                                            .lineLimit(1)
                                        Text(path)
                                            .font(.system(size: 9))
                                            .foregroundStyle(AnvilColor.textTertiary)
                                            .lineLimit(1)
                                    }
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
            .padding(.vertical, AnvilSpacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
            .frame(maxWidth: 360)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(filtered.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex < filtered.count {
                    onSelect(filtered[selectedIndex])
                }
                return .handled
            }
        }
    }
}

// MARK: - Context Slash Command Ticket Picker

struct SlashTicketPickerMenu: View {
    let tickets: [(id: String, title: String)]
    let filter: String
    let onSelect: (String, String) -> Void

    @State private var selectedIndex: Int = 0

    private var filtered: [(id: String, title: String)] {
        let query = filter.lowercased()
        if query.isEmpty { return Array(tickets.prefix(20)) }
        return tickets.filter {
            $0.id.lowercased().contains(query) || $0.title.lowercased().contains(query)
        }.prefix(20).map { $0 }
    }

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text("Select a ticket")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)

                Divider()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.offset) { index, ticket in
                            Button {
                                onSelect(ticket.id, ticket.title)
                            } label: {
                                HStack(spacing: AnvilSpacing.sm) {
                                    Image(systemName: "ticket")
                                        .font(.system(size: 10))
                                        .foregroundStyle(AnvilColor.accentPurple)
                                        .frame(width: 16)
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(ticket.title)
                                            .font(AnvilFont.sidebarItem)
                                            .foregroundStyle(AnvilColor.textPrimary)
                                            .lineLimit(1)
                                        Text(ticket.id)
                                            .font(.system(size: 9))
                                            .foregroundStyle(AnvilColor.textTertiary)
                                    }
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
            .padding(.vertical, AnvilSpacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .shadow(color: .black.opacity(0.2), radius: 12, y: -4)
            .frame(maxWidth: 360)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(filtered.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex < filtered.count {
                    let t = filtered[selectedIndex]
                    onSelect(t.id, t.title)
                }
                return .handled
            }
        }
    }
}
