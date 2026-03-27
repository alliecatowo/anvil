import SwiftUI
import AppKit

public struct AnvilCommands: Commands {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Agent Session") {
                appState.switchMode(.agent)
                appState.agentViewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])

            Divider()

            Button("Open Project...") {
                openProject()
            }
            .keyboardShortcut("o", modifiers: .command)

            Button("Load Demo Project") {
                appState.loadDemoData()
            }
        }

        CommandMenu("Mode") {
            ForEach(AnvilMode.allCases) { mode in
                if let num = mode.shortcutNumber {
                    Button(mode.rawValue) {
                        appState.switchMode(mode)
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

            Button("Command Palette") {
                appState.toggleCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)

            Button("Quick Capture") {
                appState.toggleQuickCapture()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])

            Button("Project Notes") {
                appState.toggleProjectNotes()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
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
}
