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
        .onAppear {
            viewModel.container = deps
            if viewModel.fileTree.isEmpty, let path = deps.currentProjectPath {
                viewModel.loadFileTree(from: path, using: deps.fileSystemService)
            }
            // Load git diff data for gutter decorations
            viewModel.refreshGitDiffs()
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
                    splitState.activePane.viewModel.toggleSymbolOutline()
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .foregroundStyle(
                            splitState.activePane.viewModel.isSymbolOutlineVisible
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

            Divider()

            // Center: Editor pane(s)
            editorPaneArea

            // Right: Symbol outline for active pane
            if splitState.activePane.viewModel.isSymbolOutlineVisible {
                Divider()

                SymbolOutline(viewModel: splitState.activePane.viewModel)
                    .frame(width: 220)
                    .background(AnvilColor.backgroundSecondary)
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
