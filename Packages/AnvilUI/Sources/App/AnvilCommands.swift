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
            Button("New Agent Session") {
                appState.switchSpace(.build)
                appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Divider()

            Button("New Project...") {
                newProject()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift, .option])

            Button("Open Project...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Switch Project...") {
                appState.toggleProjectSwitcher()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Project Info...") {
                appState.toggleProjectInfo()
            }

            Divider()

            Button("Load Demo Project") {
                appState.loadDemoData()
            }
        }

        CommandMenu("Space") {
            ForEach(AnvilSpace.allCases) { space in
                if let num = space.shortcutNumber {
                    Button(space.rawValue) {
                        appState.switchSpace(space)
                    }
                    .keyboardShortcut(KeyEquivalent(Character(String(num))), modifiers: .command)
                }
            }
        }

        CommandMenu("View") {
            Button("Toggle Sidebar") {
                appState.toggleSidebar()
            }
            .keyboardShortcut("b", modifiers: .command)

            Button("Toggle Inspector") {
                appState.toggleInspector()
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Toggle Terminal") {
                appState.toggleTerminal()
            }
            .keyboardShortcut("j", modifiers: .command)

            Divider()

            Button("Command Palette / Inline Edit") {
                if appState.currentSpace == .build {
                    appState.triggerInlineEdit = true
                } else {
                    appState.toggleCommandPalette()
                }
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Find in File") {
                if appState.currentSpace == .build {
                    appState.triggerFindInFile = true
                }
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Find in Project") {
                appState.toggleProjectSearch()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Go to File...") {
                appState.openFilePalette()
            }
            .keyboardShortcut("p", modifiers: .command)

            Button("Go to Symbol...") {
                appState.openSymbolPalette()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Go to Line...") {
                appState.isGoToLineVisible = true
            }
            .keyboardShortcut("g", modifiers: .control)

            Button("Quick Capture") {
                appState.toggleQuickCapture()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])

            Button("Project Notes") {
                appState.toggleProjectNotes()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Ask Codebase (Q&A)") {
                appState.toggleCodebaseQA()
            }
            .keyboardShortcut("/", modifiers: .command)

            Divider()

            Button("New Terminal Session") {
                appState.switchSpace(.build)
                _ = appState.terminalViewModel.addTab()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("Split Editor Right") {
                appState.triggerSplitVertical = true
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("Split Editor Down") {
                appState.triggerSplitHorizontal = true
            }
            .keyboardShortcut("\\", modifiers: [.command, .shift])
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
