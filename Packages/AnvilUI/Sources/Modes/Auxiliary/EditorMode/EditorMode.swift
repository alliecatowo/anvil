import SwiftUI

struct EditorMode: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject private var deps: DependencyContainer

    var body: some View {
        Group {
            if viewModel.fileTree.isEmpty && deps.currentProjectPath == nil {
                AnvilEmptyState(
                    icon: "doc.text",
                    title: "Open a project",
                    message: "Select a folder to start editing.",
                    actions: [
                        EmptyStateAction("Open Project", icon: "folder", style: .primary) {
                            openProject()
                        }
                    ]
                )
            } else {
                editorContent
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .onAppear {
            if viewModel.fileTree.isEmpty, let path = deps.currentProjectPath {
                viewModel.loadFileTree(from: path, using: deps.fileSystemService)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.toggleSymbolOutline()
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .foregroundStyle(
                            viewModel.isSymbolOutlineVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .help("Toggle Symbol Outline")
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        HStack(spacing: 0) {
            // Left: File tree sidebar
            EditorSidebar(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Center: Code editor
            VStack(spacing: 0) {
                EditorTabBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                BreadcrumbBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                EditorView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Right: Symbol outline (toggleable)
            if viewModel.isSymbolOutlineVisible {
                Divider().overlay(AnvilColor.borderSubtle)

                SymbolOutline(viewModel: viewModel)
                    .frame(width: 220)
                    .background(AnvilColor.backgroundSecondary)
            }
        }
    }

    // MARK: - Open Project

    private func openProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a project folder"
        if panel.runModal() == .OK, let url = panel.url {
            deps.currentProjectPath = url.path
            viewModel.loadFileTree(from: url.path, using: deps.fileSystemService)
        }
    }
}
