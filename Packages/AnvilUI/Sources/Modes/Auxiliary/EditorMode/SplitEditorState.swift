import SwiftUI

// MARK: - Split Direction

enum SplitDirection: String, CaseIterable {
    case none       // Single pane
    case vertical   // Side by side (⌘\)
    case horizontal // Top and bottom (⌘⇧\)
}

// MARK: - Editor Pane

/// Represents a single editor pane with its own file state.
class EditorPane: ObservableObject, Identifiable {
    let id = UUID()
    @Published var viewModel: EditorViewModel

    init(viewModel: EditorViewModel = EditorViewModel()) {
        self.viewModel = viewModel
    }
}

// MARK: - Split Editor State

/// Manages split pane layout for the editor.
@MainActor
class SplitEditorState: ObservableObject {
    @Published var splitDirection: SplitDirection = .none
    @Published var panes: [EditorPane] = []
    @Published var activePaneId: UUID?

    /// The primary pane (always exists).
    var primaryPane: EditorPane {
        panes[0]
    }

    /// The secondary pane (exists only when split).
    var secondaryPane: EditorPane? {
        panes.count > 1 ? panes[1] : nil
    }

    var activePane: EditorPane {
        if let id = activePaneId {
            return panes.first { $0.id == id } ?? primaryPane
        }
        return primaryPane
    }

    init(primaryViewModel: EditorViewModel) {
        let pane = EditorPane(viewModel: primaryViewModel)
        self.panes = [pane]
        self.activePaneId = pane.id
    }

    // MARK: - Split Actions

    func splitVertical(projectPath: String?, fileSystemService: FileSystemService) {
        guard panes.count == 1 else { return }
        let newVM = EditorViewModel()
        if let path = projectPath {
            newVM.loadFileTree(from: path, using: fileSystemService)
        }
        // Copy the currently selected file to the new pane
        if let file = primaryPane.viewModel.selectedFile {
            newVM.openFiles = [file]
            newVM.selectedFileId = file.id
        }
        let newPane = EditorPane(viewModel: newVM)
        panes.append(newPane)
        splitDirection = .vertical
        activePaneId = newPane.id
    }

    func splitHorizontal(projectPath: String?, fileSystemService: FileSystemService) {
        guard panes.count == 1 else { return }
        let newVM = EditorViewModel()
        if let path = projectPath {
            newVM.loadFileTree(from: path, using: fileSystemService)
        }
        if let file = primaryPane.viewModel.selectedFile {
            newVM.openFiles = [file]
            newVM.selectedFileId = file.id
        }
        let newPane = EditorPane(viewModel: newVM)
        panes.append(newPane)
        splitDirection = .horizontal
        activePaneId = newPane.id
    }

    func closeSplit() {
        guard panes.count > 1 else { return }
        panes = [primaryPane]
        splitDirection = .none
        activePaneId = primaryPane.id
    }

    func closePane(_ id: UUID) {
        guard panes.count > 1 else { return }
        if id == primaryPane.id {
            // Promote secondary to primary
            if let secondary = secondaryPane {
                panes = [secondary]
                activePaneId = secondary.id
            }
        } else {
            panes.removeAll { $0.id == id }
            activePaneId = primaryPane.id
        }
        splitDirection = .none
    }

    func setActivePane(_ id: UUID) {
        activePaneId = id
    }
}
