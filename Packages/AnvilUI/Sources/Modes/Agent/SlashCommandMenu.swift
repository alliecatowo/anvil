import SwiftUI
import AnvilDomain

struct SlashCommand: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let autoSend: Bool

    static let all: [SlashCommand] = [
        SlashCommand(id: "review", name: "/review", description: "AI review on current branch", icon: "checkmark.circle", autoSend: true),
        SlashCommand(id: "commit", name: "/commit", description: "Auto-commit with AI message", icon: "arrow.up.circle", autoSend: true),
        SlashCommand(id: "test", name: "/test", description: "Run tests", icon: "testtube.2", autoSend: true),
        SlashCommand(id: "explain", name: "/explain", description: "Explain selected code", icon: "text.bubble", autoSend: false),
        SlashCommand(id: "fix", name: "/fix", description: "Fix the current error", icon: "wrench", autoSend: true),
        SlashCommand(id: "refactor", name: "/refactor", description: "Refactor selected code", icon: "arrow.2.squarepath", autoSend: false),
        SlashCommand(id: "docs", name: "/docs", description: "Generate documentation", icon: "doc.text.magnifyingglass", autoSend: false),
        SlashCommand(id: "search", name: "/search", description: "Search the codebase", icon: "magnifyingglass", autoSend: false),
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

                Divider().overlay(AnvilColor.borderSubtle)

                ForEach(Array(filtered.enumerated()), id: \.element.id) { index, command in
                    Button {
                        onSelect(command)
                    } label: {
                        HStack(spacing: AnvilSpacing.sm) {
                            Image(systemName: command.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AnvilColor.accentPurple)
                                .frame(width: 20)

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
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(AnvilColor.accentGreen.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                        }
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(index == selectedIndex ? AnvilColor.backgroundTertiary : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        if isHovered { selectedIndex = index }
                    }
                }
            }
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundElevated)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(AnvilColor.borderMedium, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
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
