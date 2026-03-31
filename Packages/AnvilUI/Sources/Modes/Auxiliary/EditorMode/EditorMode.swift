import SwiftUI

struct EditorMode: View {
    @EnvironmentObject private var deps: DependencyContainer
    @EnvironmentObject private var appState: AppState

    private var viewModel: EditorViewModel { appState.editorViewModel }
    private var splitState: SplitEditorState { appState.splitEditorState }

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
        .task {
            if let path = deps.currentProjectPath {
                await viewModel.lspViewModel.start(workspacePath: path)
            }
        }
        .onAppear {
            viewModel.container = deps
            if viewModel.fileTree.isEmpty, let path = deps.currentProjectPath {
                viewModel.loadFileTree(from: path, using: deps.fileSystemService)
            }
            // Load git diff data for gutter decorations
            viewModel.refreshGitDiffs()
            // Start watching for external file changes
            viewModel.startFileWatching()
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
        .onChange(of: appState.triggerSaveFile) { _, trigger in
            if trigger {
                appState.triggerSaveFile = false
                splitState.activePane.viewModel.saveCurrentFile()
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
                splitState.activePane.viewModel.toggleFindBar()
            }
        }
        .onChange(of: appState.triggerSplitVertical) { _, trigger in
            if trigger {
                appState.triggerSplitVertical = false
                splitState.splitVertical(
                    projectPath: deps.currentProjectPath,
                    fileSystemService: deps.fileSystemService
                )
            }
        }
        .onChange(of: appState.triggerSplitHorizontal) { _, trigger in
            if trigger {
                appState.triggerSplitHorizontal = false
                splitState.splitHorizontal(
                    projectPath: deps.currentProjectPath,
                    fileSystemService: deps.fileSystemService
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    appState.toggleSourceControl()
                    if appState.isSourceControlVisible {
                        appState.isInspectorVisible = true
                    }
                } label: {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(
                            appState.isSourceControlVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .accessibilityLabel("Toggle Source Control")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Source Control (Ctrl+Shift+G)")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    splitState.activePane.viewModel.toggleSymbolOutline()
                    if splitState.activePane.viewModel.isSymbolOutlineVisible {
                        appState.isInspectorVisible = true
                    }
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .foregroundStyle(
                            splitState.activePane.viewModel.isSymbolOutlineVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .accessibilityLabel("Toggle Symbol Outline")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Symbol Outline")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.isProblemsVisible.toggle()
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(
                            viewModel.isProblemsVisible
                                ? AnvilColor.accentBlue
                                : viewModel.lspViewModel.diagnostics.isEmpty
                                    ? AnvilColor.textTertiary
                                    : AnvilColor.accentAmber
                        )
                }
                .accessibilityLabel("Toggle Problems Panel")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Problems Panel")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    splitState.activePane.viewModel.isMinimapVisible.toggle()
                } label: {
                    Image(systemName: "rectangle.split.3x1")
                        .foregroundStyle(
                            splitState.activePane.viewModel.isMinimapVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .accessibilityLabel("Toggle Minimap")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Minimap")
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    splitState.activePane.viewModel.toggleBlame()
                } label: {
                    Image(systemName: "person.text.rectangle")
                        .foregroundStyle(
                            splitState.activePane.viewModel.isBlameVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .accessibilityLabel("Toggle Git Blame")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Git Blame Annotations")
            }
        }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        VStack(spacing: 0) {
            editorPaneArea

            if viewModel.isProblemsVisible {
                Divider()
                ProblemsPanel(viewModel: viewModel)
                    .frame(height: 200)
            }
        }
    }

    // MARK: - Editor Pane Area

    @ViewBuilder
    private var editorPaneArea: some View {
        let primary = splitState.primaryPane
        let activeId = splitState.activePaneId

        if splitState.splitDirection == .none {
            // Single pane — no split
            EditorPaneView(
                viewModel: primary.viewModel,
                splitState: splitState,
                paneId: primary.id,
                isActive: true,
                onFocus: { splitState.setActivePane(primary.id) },
                onClose: nil
            )
        } else if let secondary = splitState.secondaryPane {
            // Split mode — use AnvilSplitView
            let orientation: SplitOrientation = splitState.splitDirection == .vertical
                ? .horizontal  // vertical split = side by side = horizontal layout
                : .vertical    // horizontal split = top/bottom = vertical layout

            AnvilSplitView(
                initialRatio: 0.5,
                minLeftWidth: 200,
                minRightWidth: 200,
                orientation: orientation
            ) {
                EditorPaneView(
                    viewModel: primary.viewModel,
                    splitState: splitState,
                    paneId: primary.id,
                    isActive: activeId == primary.id,
                    onFocus: { splitState.setActivePane(primary.id) },
                    onClose: { splitState.closePane(primary.id) }
                )
            } right: {
                EditorPaneView(
                    viewModel: secondary.viewModel,
                    splitState: splitState,
                    paneId: secondary.id,
                    isActive: activeId == secondary.id,
                    onFocus: { splitState.setActivePane(secondary.id) },
                    onClose: { splitState.closePane(secondary.id) }
                )
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
                .accessibilityHidden(true)

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
            .accessibilityLabel("Enable Editing")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.accentAmber.opacity(0.08))
        .accessibilityElement(children: .combine)
    }
}
