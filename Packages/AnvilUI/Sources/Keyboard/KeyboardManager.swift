import SwiftUI

@MainActor
public class KeyboardManager: ObservableObject {
    @Published public var currentContext: KeybindingContext = .global

    private let chordTracker = ChordTracker()
    private var actionHandler: ((String) -> Void)?

    public init() {}

    public func setActionHandler(_ handler: @escaping (String) -> Void) {
        self.actionHandler = handler
    }

    public func setContext(_ context: KeybindingContext) {
        currentContext = context
    }

    public func handleAction(_ action: String, appState: AppState) {
        switch action {
        case "commandPalette": appState.toggleCommandPalette()
        case "toggleSidebar": appState.toggleSidebar()
        case "toggleInspector": appState.toggleInspector()
        case "toggleTerminal": appState.toggleTerminal()
        case "mode.intent": appState.switchMode(.intent)
        case "mode.agent": appState.switchMode(.agent)
        case "mode.review": appState.switchMode(.review)
        case "mode.ship": appState.switchMode(.ship)
        case "mode.editor": appState.switchMode(.editor)
        case "mode.database": appState.switchMode(.database)
        case "mode.terminal": appState.switchMode(.terminal)
        case "mode.docs": appState.switchMode(.docs)
        case "mode.messaging": appState.switchMode(.messaging)
        case "mode.notifications": appState.switchMode(.notifications)
        default:
            actionHandler?(action)
        }
    }
}
