import SwiftUI

struct EditorMode: View {
    @EnvironmentObject private var deps: DependencyContainer
    @EnvironmentObject private var appState: AppState

    private var viewModel: EditorViewModel { appState.editorViewModel }

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
            // Handle file open request from command palette
            if let filePath = appState.pendingFileToOpen {
                openPendingFile(filePath)
            }
        }
        .onChange(of: appState.pendingFileToOpen) { _, newPath in
            if let filePath = newPath {
                openPendingFile(filePath)
            }
        }
        .onChange(of: appState.triggerInlineEdit) { _, trigger in
            if trigger {
                appState.triggerInlineEdit = false
                handleCmdK()
            }
        }
        .onChange(of: appState.triggerFindInFile) { _, trigger in
            if trigger {
                appState.triggerFindInFile = false
                viewModel.toggleFindBar()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.toggleSourceControl()
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(
                            appState.isSourceControlVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .help("Toggle Source Control (Ctrl+Shift+G)")
            }

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
            // Left: File tree sidebar or Source Control panel
            if appState.isSourceControlVisible {
                SourceControlPanel()
                    .frame(width: AnvilSpacing.sidebarWidth)
                    .background(AnvilColor.backgroundSecondary)
            } else {
                EditorSidebar(viewModel: viewModel)
                    .frame(width: AnvilSpacing.sidebarWidth)
                    .background(AnvilColor.backgroundSecondary)
            }

            Divider().overlay(AnvilColor.borderSubtle)

            // Center: Code editor
            VStack(spacing: 0) {
                EditorTabBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                BreadcrumbBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                // Find & Replace bar
                if viewModel.isFindBarVisible {
                    FindReplaceBar(viewModel: viewModel)

                    Divider().overlay(AnvilColor.borderSubtle)
                }

                // Read-only banner
                if viewModel.isSelectedFileReadOnly {
                    ReadOnlyBanner(viewModel: viewModel)
                }

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

    // MARK: - Pending File from Command Palette

    private func openPendingFile(_ filePath: String) {
        // Ensure tree is loaded first
        if viewModel.fileTree.isEmpty, let path = deps.currentProjectPath {
            viewModel.loadFileTree(from: path, using: deps.fileSystemService)
        }
        viewModel.openFileFromTree(filePath)
        // Navigate to symbol line if set
        if let line = appState.pendingSymbolLine {
            viewModel.cursorLine = line
            appState.pendingSymbolLine = nil
        }
        appState.pendingFileToOpen = nil
    }

    // MARK: - Inline Edit (⌘K)

    private func handleCmdK() {
        if viewModel.inlineEditPhase != .hidden {
            viewModel.cancelInlineEdit()
            return
        }
        guard viewModel.selectedFile != nil else { return }

        let range = viewModel.inlineEditSelectedRange
        let effectiveRange: ClosedRange<Int>
        if range.count > 1 {
            effectiveRange = range
        } else {
            effectiveRange = viewModel.cursorLine...viewModel.cursorLine
        }
        viewModel.beginInlineEdit(range: effectiveRange)
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

// MARK: - Read-Only Banner

struct ReadOnlyBanner: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentAmber)

            Text("This file is read-only")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            Button("Enable Editing") {
                if let id = viewModel.selectedFileId {
                    viewModel.toggleReadOnly(for: id)
                }
            }
            .font(AnvilFont.label)
            .buttonStyle(.plain)
            .foregroundStyle(AnvilColor.accentBlue)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.accentAmber.opacity(0.08))
    }
}
