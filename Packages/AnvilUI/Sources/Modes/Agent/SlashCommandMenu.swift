import SwiftUI
import AnvilDomain

struct SlashCommand: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String

    static let all: [SlashCommand] = [
        SlashCommand(id: "review", name: "/review", description: "AI review on current branch", icon: "checkmark.circle"),
        SlashCommand(id: "commit", name: "/commit", description: "Auto-commit with AI message", icon: "arrow.up.circle"),
        SlashCommand(id: "test", name: "/test", description: "Run tests", icon: "testtube.2"),
        SlashCommand(id: "explain", name: "/explain", description: "Explain selected code", icon: "text.bubble"),
        SlashCommand(id: "fix", name: "/fix", description: "Fix the current error", icon: "wrench"),
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

    @State private var hoveredId: String?

    var body: some View {
        if !filtered.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtered) { command in
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
                        }
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(hoveredId == command.id ? AnvilColor.backgroundTertiary : .clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        hoveredId = isHovered ? command.id : nil
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
        }
    }
}
