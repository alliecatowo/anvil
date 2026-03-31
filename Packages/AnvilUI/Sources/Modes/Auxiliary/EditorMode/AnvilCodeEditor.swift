import SwiftUI
import AppKit
import CodeEditSourceEditor
import CodeEditLanguages
import AnvilEditor

// MARK: - Anvil Editor Theme (Nord-inspired)

/// Builds an ``EditorTheme`` using the Nord palette so the source editor matches the rest of the app.
@MainActor
private func makeAnvilEditorTheme() -> EditorTheme {
    // Nord palette
    let bg        = NSColor(srgbRed: 0x2E / 255.0, green: 0x34 / 255.0, blue: 0x40 / 255.0, alpha: 1) // nord0
    let lineHL    = NSColor(srgbRed: 0x3B / 255.0, green: 0x42 / 255.0, blue: 0x52 / 255.0, alpha: 1) // nord1
    let selection = NSColor(srgbRed: 0x43 / 255.0, green: 0x4C / 255.0, blue: 0x5E / 255.0, alpha: 1) // nord2
    let fg        = NSColor(srgbRed: 0xEC / 255.0, green: 0xEF / 255.0, blue: 0xF4 / 255.0, alpha: 1) // nord6
    let comment   = NSColor(srgbRed: 0x61 / 255.0, green: 0x6E / 255.0, blue: 0x88 / 255.0, alpha: 1) // nord3-bright
    let purple    = NSColor(srgbRed: 0xB4 / 255.0, green: 0x8E / 255.0, blue: 0xAD / 255.0, alpha: 1) // nord15
    let green     = NSColor(srgbRed: 0xA3 / 255.0, green: 0xBE / 255.0, blue: 0x8C / 255.0, alpha: 1) // nord14
    let blue      = NSColor(srgbRed: 0x81 / 255.0, green: 0xA1 / 255.0, blue: 0xC1 / 255.0, alpha: 1) // nord9
    let teal      = NSColor(srgbRed: 0x8F / 255.0, green: 0xBC / 255.0, blue: 0xBB / 255.0, alpha: 1) // nord7
    let amber     = NSColor(srgbRed: 0xEB / 255.0, green: 0xCB / 255.0, blue: 0x8B / 255.0, alpha: 1) // nord13
    let red       = NSColor(srgbRed: 0xBF / 255.0, green: 0x61 / 255.0, blue: 0x6A / 255.0, alpha: 1) // nord11
    let orange    = NSColor(srgbRed: 0xD0 / 255.0, green: 0x87 / 255.0, blue: 0x70 / 255.0, alpha: 1) // nord12

    return EditorTheme(
        text:           .init(color: fg),
        insertionPoint: fg,
        invisibles:     .init(color: comment.withAlphaComponent(0.4)),
        background:     bg,
        lineHighlight:  lineHL,
        selection:      selection,
        keywords:       .init(color: purple, bold: true),
        commands:       .init(color: blue),
        types:          .init(color: teal),
        attributes:     .init(color: purple.withAlphaComponent(0.8)),
        variables:      .init(color: fg),
        values:         .init(color: orange),
        numbers:        .init(color: amber),
        strings:        .init(color: green),
        characters:     .init(color: green),
        comments:       .init(color: comment, italic: true)
    )
}

// MARK: - AnvilEditorCoordinator

/// A ``TextViewCoordinator`` that bridges cursor position and text changes
/// from the CodeEditSourceEditor back into the Anvil ``EditorViewModel``.
@MainActor
final class AnvilEditorCoordinator: TextViewCoordinator, @unchecked Sendable {
    private weak var viewModel: EditorViewModel?
    private let fileId: UUID
    private let filePath: String
    private weak var controller: TextViewController?

    init(viewModel: EditorViewModel, fileId: UUID, filePath: String) {
        self.viewModel = viewModel
        self.fileId = fileId
        self.filePath = filePath
    }

    func prepareCoordinator(controller: TextViewController) {
        self.controller = controller
    }

    func textViewDidChangeText(controller: TextViewController) {
        guard let viewModel else { return }
        let newText = controller.text
        // Find the file by path since EditorFile.id changes on every content update
        if let index = viewModel.openFiles.firstIndex(where: { $0.path == filePath }) {
            let file = viewModel.openFiles[index]
            if file.content != newText {
                let updated = EditorFile(
                    name: file.name,
                    path: file.path,
                    content: newText,
                    language: file.language,
                    relativePath: file.relativePath
                )
                viewModel.openFiles[index] = updated
                viewModel.selectedFileId = updated.id
                viewModel.markDirty(updated.id)
            }
        }
    }

    func textViewDidChangeSelection(controller: TextViewController, newPositions: [CursorPosition]) {
        guard let viewModel, let first = newPositions.first else { return }
        let line = first.start.line
        let col = first.start.column
        if line > 0 { viewModel.cursorLine = line }
        if col > 0 { viewModel.cursorColumn = col }
    }

    func destroy() {
        controller = nil
    }
}

// MARK: - AnvilCodeEditor

/// Wraps CodeEditSourceEditor's ``SourceEditor`` as a SwiftUI view, wired into ``EditorViewModel``.
struct AnvilCodeEditor: View {
    @ObservedObject var viewModel: EditorViewModel
    let file: EditorFile

    @State private var editorState = SourceEditorState(
        cursorPositions: [CursorPosition(line: 1, column: 1)]
    )
    @State private var textContent: String = ""
    @State private var coordinator: AnvilEditorCoordinator?

    private var language: CodeLanguage {
        CodeLanguage.detectLanguageFrom(
            url: URL(fileURLWithPath: file.path)
        )
    }

    private var configuration: SourceEditorConfiguration {
        SourceEditorConfiguration(
            appearance: .init(
                theme: makeAnvilEditorTheme(),
                useThemeBackground: true,
                font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
                lineHeightMultiple: 1.45,
                wrapLines: viewModel.isWordWrapEnabled,
                tabWidth: viewModel.tabSize
            ),
            behavior: .init(
                isEditable: !viewModel.readOnlyFileIds.contains(file.id),
                indentOption: .spaces(count: viewModel.tabSize)
            ),
            peripherals: .init(
                showMinimap: viewModel.isMinimapVisible,
                showFoldingRibbon: viewModel.codeFoldingEnabled
            )
        )
    }

    var body: some View {
        SourceEditor(
            $textContent,
            language: language,
            configuration: configuration,
            state: $editorState,
            coordinators: coordinator.map { [$0] } ?? []
        )
        .onAppear {
            textContent = file.content
            let coord = AnvilEditorCoordinator(
                viewModel: viewModel,
                fileId: file.id,
                filePath: file.path
            )
            coordinator = coord
        }
        .onChange(of: file.path) { _, _ in
            // When switching to a different file (by path), update text and coordinator
            textContent = file.content
            let coord = AnvilEditorCoordinator(
                viewModel: viewModel,
                fileId: file.id,
                filePath: file.path
            )
            coordinator = coord
        }
        .onChange(of: editorState.cursorPositions) { _, newPositions in
            // Sync cursor from SourceEditor state back to view model
            if let first = newPositions?.first, first.start.line > 0, first.start.column > 0 {
                viewModel.cursorLine = first.start.line
                viewModel.cursorColumn = first.start.column
            }
        }
    }
}
