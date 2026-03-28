import SwiftUI

public struct ProjectNotes: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = ProjectNotesViewModel()
    @State private var appendText = ""
    @FocusState private var isAppendFocused: Bool

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "doc.text")
                    .foregroundStyle(AnvilColor.accentPurple)
                Text("Project Notes")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(AnvilSpacing.md)

            Divider()

            // Markdown editor (monospace)
            TextEditor(text: $viewModel.content)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(AnvilSpacing.sm)

            Divider()

            // Quick append bar
            HStack(spacing: AnvilSpacing.sm) {
                TextField("Append a note...", text: $appendText)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.body)
                    .focused($isAppendFocused)

                Button("Add") {
                    appendEntry()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appendText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(AnvilSpacing.md)
        }
        .background(.background)
        .onAppear {
            viewModel.load()
        }
        .onKeyPress(.return) {
            appendEntry()
            return .handled
        }
        .onExitCommand {
            dismiss()
        }
    }

    // MARK: - Actions

    private func appendEntry() {
        let trimmed = appendText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        viewModel.appendEntry(trimmed)
        appendText = ""
    }

    private func dismiss() {
        withAnimation(AnvilAnimation.standard) {
            appState.isProjectNotesVisible = false
        }
    }
}
