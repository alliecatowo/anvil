import SwiftUI

public struct AnvilCommands: Commands {
    @ObservedObject public var appState: AppState

    public init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Item") {
                // Context-dependent new item
            }
            .keyboardShortcut("n", modifiers: .command)

            Button("New Agent Session") {
                appState.switchMode(.agent)
            }
            .keyboardShortcut("a", modifiers: [.command, .shift])
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
        }
    }
}
