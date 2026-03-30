import SwiftUI
import AnvilApplication

// MARK: - Rules Editor ViewModel

@MainActor
final class RulesEditorViewModel: ObservableObject {
    @Published var rulesContent: String = ""
    @Published var isDirty: Bool = false
    @Published var saveMessage: String?
    @Published var isLoaded: Bool = false

    private let service = ProjectRulesService()
    private var projectPath: String?

    var rulesFilePath: String? {
        guard let projectPath else { return nil }
        return service.rulesPath(projectPath: projectPath)
    }

    func load(projectPath: String?) {
        self.projectPath = projectPath
        guard let projectPath else {
            rulesContent = ""
            isLoaded = false
            return
        }

        if let content = service.loadRules(projectPath: projectPath) {
            rulesContent = content
        } else {
            rulesContent = defaultRulesTemplate
        }
        isDirty = false
        isLoaded = true
    }

    func save() {
        guard let projectPath else {
            saveMessage = "No project open"
            return
        }

        do {
            try service.saveRules(rulesContent, projectPath: projectPath)
            isDirty = false
            saveMessage = "Saved"

            // Clear message after a short delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if self.saveMessage == "Saved" {
                    self.saveMessage = nil
                }
            }
        } catch {
            saveMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private var defaultRulesTemplate: String {
        """
        # Project Rules

        These rules are injected as system context for every agent session in this project.

        ## Coding Standards

        - Follow existing code style and conventions
        - Write tests for new functionality

        ## Architecture

        - Keep modules loosely coupled
        - Use dependency injection

        ## Guidelines

        - Prefer clarity over cleverness
        - Document non-obvious decisions
        """
    }
}

// MARK: - Rules Editor View

struct RulesEditorView: View {
    @StateObject private var viewModel = RulesEditorViewModel()
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Editor
            if viewModel.isLoaded {
                editorArea
            } else {
                AnvilEmptyState(
                    icon: "doc.text",
                    title: "No project open",
                    message: "Open a project to edit its agent rules."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.load(projectPath: appState.currentProjectPath)
        }
        .onChange(of: appState.currentProjectPath) { _, newPath in
            viewModel.load(projectPath: newPath)
        }
    }

    private var header: some View {
        HStack(spacing: AnvilSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Project Rules")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                if let path = viewModel.rulesFilePath {
                    Text(path)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if let message = viewModel.saveMessage {
                Text(message)
                    .font(AnvilFont.label)
                    .foregroundStyle(message == "Saved" ? AnvilColor.accentGreen : AnvilColor.accentRed)
                    .transition(.opacity)
            }

            if viewModel.isDirty {
                Circle()
                    .fill(AnvilColor.accentAmber)
                    .frame(width: 8, height: 8)
                    .help("Unsaved changes")
            }

            Button("Save") {
                viewModel.save()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!viewModel.isDirty)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
    }

    private var editorArea: some View {
        TextEditor(text: $viewModel.rulesContent)
            .font(.system(.body, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(AnvilColor.backgroundPrimary)
            .padding(AnvilSpacing.md)
            .onChange(of: viewModel.rulesContent) { _, _ in
                viewModel.isDirty = true
            }
            .accessibilityLabel("Project rules editor")
    }
}
