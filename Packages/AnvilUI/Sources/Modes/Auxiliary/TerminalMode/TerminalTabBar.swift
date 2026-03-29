import SwiftUI
import AnvilTerminal

struct TerminalTabBar: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(viewModel.sessions) { session in
                        TerminalTabItem(
                            session: session,
                            isSelected: viewModel.selectedSessionId == session.id,
                            canClose: viewModel.sessions.count > 1,
                            onSelect: { viewModel.selectTab(session.id) },
                            onClose: { viewModel.closeTab(session.id) },
                            onRename: { newTitle in
                                viewModel.renameSession(session.id, title: newTitle)
                            }
                        )
                    }
                }
                .padding(.horizontal, AnvilSpacing.xs)
            }

            Spacer()

            HStack(spacing: AnvilSpacing.xs) {
                // New tab
                Button {
                    viewModel.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("New Terminal (\u{2318}T)")
                .accessibilityLabel("New Terminal Tab")
                .keyboardShortcut("t", modifiers: .command)

                // Close current tab
                Button {
                    if let id = viewModel.selectedSessionId {
                        viewModel.closeTab(id)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Close Terminal (\u{2318}W)")
                .accessibilityLabel("Close Current Terminal")
                .keyboardShortcut("w", modifiers: .command)
                .disabled(viewModel.sessions.count <= 1)
            }
            .padding(.trailing, AnvilSpacing.sm)

            // Tab switching shortcuts (hidden)
            Button("") { viewModel.selectNextTab() }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .hidden()
                .frame(width: 0, height: 0)

            Button("") { viewModel.selectPreviousTab() }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .hidden()
                .frame(width: 0, height: 0)
        }
        .frame(height: 32)
        .background(AnvilColor.backgroundSecondary)
    }
}

// MARK: - Tab Item

private struct TerminalTabItem: View {
    @ObservedObject var session: TerminalSession
    let isSelected: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: (String) -> Void

    @State private var isEditing = false
    @State private var editText = ""
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                .accessibilityHidden(true)

            if isEditing {
                TextField("", text: $editText, onCommit: {
                    commitRename()
                })
                .textFieldStyle(.plain)
                .font(AnvilFont.label)
                .frame(minWidth: 40, maxWidth: 120)
                .onExitCommand { cancelRename() }
            } else {
                Text(session.title)
                    .font(AnvilFont.label)
                    .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                    .lineLimit(1)
            }

            if !session.isRunning {
                Circle()
                    .fill(AnvilColor.textTertiary)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel("Exited")
            }

            if canClose && (isSelected || isHovered) {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(session.title)")
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: 32)
        .background(isSelected ? AnvilColor.backgroundTertiary : (isHovered ? AnvilColor.backgroundSecondary.opacity(0.5) : Color.clear))
        .overlay(
            Rectangle()
                .fill(isSelected ? AnvilColor.accentBlue : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            startRename()
        }
        .onTapGesture(count: 1) {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title)\(isSelected ? ", selected" : ""), \(session.isRunning ? "running" : "exited")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func startRename() {
        editText = session.title
        isEditing = true
    }

    private func commitRename() {
        let trimmed = editText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            onRename(trimmed)
        }
        isEditing = false
    }

    private func cancelRename() {
        isEditing = false
    }
}
