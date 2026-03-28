import SwiftUI
import AnvilDomain

struct SlashCommand: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let autoSend: Bool
    /// The prompt template inserted into the input when the command is selected.
    /// For non-auto-send commands, the user can append context after the template.
    let promptTemplate: String

    static let all: [SlashCommand] = [
        SlashCommand(
            id: "fix",
            name: "/fix",
            description: "Fix the bug",
            icon: "wrench",
            autoSend: false,
            promptTemplate: "Please fix the following issue in the current file:\n\n"
        ),
        SlashCommand(
            id: "explain",
            name: "/explain",
            description: "Explain this code",
            icon: "text.magnifyingglass",
            autoSend: false,
            promptTemplate: "Please explain what this code does, step by step:\n\n"
        ),
        SlashCommand(
            id: "test",
            name: "/test",
            description: "Generate tests",
            icon: "checkmark.circle",
            autoSend: false,
            promptTemplate: "Please write comprehensive tests for the following code:\n\n"
        ),
        SlashCommand(
            id: "commit",
            name: "/commit",
            description: "Write commit message",
            icon: "arrow.up.circle",
            autoSend: true,
            promptTemplate: "Please write a conventional commit message for the current staged changes."
        ),
        SlashCommand(
            id: "pr",
            name: "/pr",
            description: "Create PR description",
            icon: "arrow.triangle.pull",
            autoSend: false,
            promptTemplate: "Please write a pull request description for the following changes:\n\n"
        ),
        SlashCommand(
            id: "review",
            name: "/review",
            description: "Review this diff",
            icon: "eyes",
            autoSend: false,
            promptTemplate: "Please review the following code changes and provide feedback:\n\n"
        ),
        SlashCommand(
            id: "doc",
            name: "/doc",
            description: "Generate documentation",
            icon: "doc.text",
            autoSend: false,
            promptTemplate: "Please generate comprehensive documentation (docstrings/comments) for:\n\n"
        ),
        SlashCommand(
            id: "refactor",
            name: "/refactor",
            description: "Refactor this code",
            icon: "arrow.triangle.2.circlepath",
            autoSend: false,
            promptTemplate: "Please refactor the following code to improve readability, performance, and maintainability:\n\n"
        ),
    ]
}

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

                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, command in
                    Button {
                        onSelect(command)
                    } label: {
                        HStack(spacing: AnvilSpacing.sm) {
                            Image(systemName: command.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AnvilColor.accentPurple)
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
}
