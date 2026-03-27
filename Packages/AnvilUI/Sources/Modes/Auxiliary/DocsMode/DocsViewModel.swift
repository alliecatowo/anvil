import SwiftUI

// MARK: - Models

struct DocNode: Identifiable {
    let id = UUID()
    let name: String
    let isFolder: Bool
    let children: [DocNode]
    let content: String?

    init(name: String, isFolder: Bool = false, children: [DocNode] = [], content: String? = nil) {
        self.name = name
        self.isFolder = isFolder
        self.children = children
        self.content = content
    }
}

// MARK: - ViewModel

@MainActor
class DocsViewModel: ObservableObject {
    @Published var docTree: [DocNode] = []
    @Published var selectedDocId: UUID?
    @Published var expandedFolderIds: Set<UUID> = []
    @Published var editorContent: String = ""

    var selectedDoc: DocNode? {
        findNode(id: selectedDocId, in: docTree)
    }

    init() {
        let architectureContent = """
        # Architecture

        ## Overview

        Anvil uses a modular Swift Package structure with three core packages:

        - **AnvilDomain** - Domain primitives, protocols, and value types
        - **AnvilEngine** - Business logic, services, and orchestration
        - **AnvilUI** - SwiftUI views, design system, and mode implementations

        ## Design Principles

        1. **Separation of concerns** - Each package has a clear responsibility
        2. **Protocol-driven** - Dependencies are expressed as protocols
        3. **Unidirectional data flow** - State flows down, actions flow up
        4. **Composability** - Modes are self-contained and independently testable

        ## Mode System

        Each mode represents a distinct workspace context:

        ```
        Modes/
        ├── Core/           # Intent, Agent, Review, Ship
        └── Auxiliary/      # Editor, Database, Terminal, Docs, Messaging
        ```

        Modes are routed through `ContentArea.swift` based on the active `AnvilMode` enum case.
        """

        let gettingStartedContent = """
        # Getting Started

        ## Prerequisites

        - macOS 15.0 or later
        - Xcode 16.0 or later
        - Swift 6.0

        ## Setup

        ```bash
        git clone https://github.com/example/anvil.git
        cd anvil
        swift build
        open Anvil.xcodeproj
        ```

        ## Running

        1. Open the project in Xcode
        2. Select the Anvil scheme
        3. Press Cmd+R to build and run

        ## Project Structure

        The project is organized as a Swift Package Manager workspace with multiple packages.
        See the Architecture doc for details on each package.
        """

        let apiReferenceContent = """
        # API Reference

        ## AppState

        The central state object shared across the app via `@EnvironmentObject`.

        ```swift
        public class AppState: ObservableObject {
            @Published public var currentMode: AnvilMode
            @Published public var isSidebarVisible: Bool
        }
        ```

        ## AnvilMode

        An enum representing available workspace modes.

        ## Design System

        ### Colors
        Use `AnvilColor` for all color values. Never use raw `Color` literals.

        ### Typography
        Use `AnvilFont` for all font values. Available presets: `.body`, `.label`, `.code`, `.heading`.

        ### Spacing
        Use `AnvilSpacing` tokens for all padding and spacing values.
        """

        let changelogContent = """
        # Changelog

        ## v0.4.0 (2026-03-27)

        - Added DatabaseMode with schema explorer and query console
        - Added TerminalMode with tabbed terminal sessions
        - Added DocsMode with document browser and editor
        - Added MessagingMode with channels and chat

        ## v0.3.0 (2026-03-20)

        - Added EditorMode with syntax highlighting
        - Added Symbol Outline panel
        - Improved design system with new color tokens

        ## v0.2.0 (2026-03-10)

        - Core modes: Intent, Agent, Review, Ship
        - Command palette
        - Mode switcher sidebar
        """

        docTree = [
            DocNode(name: "Guide", isFolder: true, children: [
                DocNode(name: "Getting Started.md", content: gettingStartedContent),
                DocNode(name: "Architecture.md", content: architectureContent),
            ]),
            DocNode(name: "Reference", isFolder: true, children: [
                DocNode(name: "API Reference.md", content: apiReferenceContent),
            ]),
            DocNode(name: "Changelog.md", content: changelogContent),
        ]

        // Expand top-level folders
        for node in docTree where node.isFolder {
            expandedFolderIds.insert(node.id)
        }

        // Select first document
        if let firstDoc = docTree.first?.children.first {
            selectedDocId = firstDoc.id
            editorContent = firstDoc.content ?? ""
        }
    }

    // MARK: - Actions

    func selectDoc(_ id: UUID) {
        selectedDocId = id
        if let doc = findNode(id: id, in: docTree) {
            editorContent = doc.content ?? ""
        }
    }

    func toggleFolder(_ id: UUID) {
        if expandedFolderIds.contains(id) {
            expandedFolderIds.remove(id)
        } else {
            expandedFolderIds.insert(id)
        }
    }

    // MARK: - Helpers

    private func findNode(id: UUID?, in nodes: [DocNode]) -> DocNode? {
        guard let id else { return nil }
        for node in nodes {
            if node.id == id { return node }
            if let found = findNode(id: id, in: node.children) { return found }
        }
        return nil
    }
}
