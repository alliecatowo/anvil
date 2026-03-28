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
        case "space.plan": appState.switchSpace(.plan)
        case "space.build": appState.switchSpace(.build)
        case "space.review": appState.switchSpace(.review)
        case "space.operate": appState.switchSpace(.operate)
        case "space.library": appState.switchSpace(.library)
        default:
            actionHandler?(action)
        }
    }
}
