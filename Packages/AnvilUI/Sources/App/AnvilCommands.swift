import SwiftUI
import AppKit
import AnvilApplication

public struct AnvilCommands: Commands {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Build Session") {
                appState.switchSpace(.build)
                appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
            .help("Start a new Build session")

            Divider()

            Button("New Project...") {
                newProject()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift, .option])
            .help("Create a new project from one or more repositories")

            Button("Open Project...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: .command)
            .help("Open an existing project directory")

            Button("Switch Project...") {
                appState.toggleProjectSwitcher()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .help("Switch to a different project")

            Button("Project Info...") {
                appState.toggleProjectInfo()
            }
            .help("Show project details and settings")

            Divider()

            Button("Load Demo Project") {
                appState.loadDemoData()
            }
            .help("Load a sample project for demonstration")
        }

        CommandGroup(after: .saveItem) {
            Button("Save") {
                appState.triggerSaveFile = true
            }
            .keyboardShortcut("s", modifiers: .command)
            .help("Save the current file")
        }

        CommandMenu("Space") {
            ForEach(AnvilSpace.allCases) { space in
                if let num = space.shortcutNumber {
                    Button(space.rawValue) {
                        appState.switchSpace(space)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(num))), modifiers: .command)
                    .help("Switch to the \(space.rawValue) space")
                }
            }
        }

        CommandMenu("View") {
            Button("Toggle Sidebar") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("b", modifiers: .command)
            .help("Show or hide the sidebar")

            Button("Toggle Inspector") {
                appState.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
            .help("Show or hide the inspector panel")

            Button("Toggle Terminal") {
                appState.toggleTerminal()
            }
            .keyboardShortcut("j", modifiers: .command)
            .help("Show or hide the terminal panel")

            Divider()

            Button("Command Palette / Inline Edit") {
                if appState.currentSpace == .build {
                    appState.triggerInlineEdit = true
                } else {
                    appState.toggleCommandPalette()
                }
            }
            .keyboardShortcut("k", modifiers: .command)
            .help("Open the command palette or trigger inline edit")

            Button("Show All Commands") {
                appState.toggleCommandPalette()
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("Open the command palette with all commands")

            Button("Find in File") {
                if appState.currentSpace == .build {
                    appState.triggerFindInFile = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Search within the current file")

            Button("Find in Project") {
                appState.toggleProjectSearch()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .help("Search across all files in the project")

            Button("Go to File...") {
                appState.openFilePalette()
            }
            .keyboardShortcut("p", modifiers: .command)
            .help("Quickly open a file by name")

            Button("Go to Symbol...") {
                appState.openSymbolPalette()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .help("Jump to a symbol definition in the project")

            Button("Go to Line...") {
                appState.isGoToLineVisible = true
            }
            .keyboardShortcut("g", modifiers: .control)
            .help("Jump to a specific line number")

            Button("Quick Capture") {
                appState.toggleQuickCapture()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            .help("Capture a quick note or idea")

            Button("Project Notes") {
                appState.toggleProjectNotes()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .help("Open project notes")

            Divider()

            Button("New Terminal Session") {
                appState.switchSpace(.build)
                _ = appState.terminalViewModel.addTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .help("Open a new terminal tab")

            Button("Split Editor Right") {
                appState.triggerSplitVertical = true
            }
            .keyboardShortcut("\\", modifiers: .command)
            .help("Split the editor vertically")

            Button("Split Editor Down") {
                appState.triggerSplitHorizontal = true
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])
            .help("Split the editor horizontally")
        }

        CommandMenu("Editor") {
            Button("Close Tab") {
                appState.triggerCloseTab = true
            }
            .keyboardShortcut("w", modifiers: .command)
            .help("Close the active editor tab or terminal tab")

            Button("Toggle Line Comment") {
                appState.triggerToggleComment = true
            }
            .keyboardShortcut("/", modifiers: .command)
            .help("Comment or uncomment the current line")

            Button("Go to Definition") {
                appState.triggerGoToDefinition = true
            }
            .keyboardShortcut(KeyEquivalent(Character(UnicodeScalar(NSF12FunctionKey)!)))
            .help("Jump to the definition of the symbol under the cursor")
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.currentProjectPath = url.path
        }
    }

    private func newProject() {
        let panel = NSOpenPanel()
        panel.title = "Choose Project Directory"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "Select one or more repository directories for your new project"
        panel.prompt = "Create Project"
        if panel.runModal() == .OK, !panel.urls.isEmpty {
            let paths = panel.urls.map(\.path)
            let name = panel.urls.first.map { $0.lastPathComponent } ?? "New Project"
            // Store the project via AppState/container later when wired
            appState.currentProjectPath = paths.first
            appState.currentProject = Project(name: name, repoPaths: paths)
        }
    }
}
