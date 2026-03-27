import SwiftUI

// MARK: - KeyEventRouter

/// View modifier that captures non-modifier key events and routes them through
/// the chord tracker and context-specific keybindings before falling back to global bindings.
/// Modifier-based shortcuts (⌘1, ⌘K, etc.) are handled by AnvilCommands menu items.
struct KeyEventRouter: ViewModifier {
    @EnvironmentObject var appState: AppState
    @StateObject private var chordTracker = ChordTracker()
    @StateObject private var keyboardManager = KeyboardManager()

    func body(content: Content) -> some View {
        content
            .onKeyPress(phases: .down) { keyPress in
                handleKeyPress(keyPress)
            }
            .environmentObject(keyboardManager)
            .environmentObject(chordTracker)
            .overlay(alignment: .bottom) {
                if chordTracker.isChordActive {
                    ChordIndicator(pendingKey: chordTracker.pendingKey)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(AnvilAnimation.standard, value: chordTracker.isChordActive)
    }

    // MARK: - Key Routing

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        // Skip when modifier keys are held — those are handled by AnvilCommands
        let hasModifiers = keyPress.modifiers.contains(.command)
            || keyPress.modifiers.contains(.control)
            || keyPress.modifiers.contains(.option)
        if hasModifiers { return .ignored }

        // Skip when command palette, quick capture, or any overlay is active
        if appState.isCommandPaletteVisible || appState.isQuickCaptureVisible {
            return .ignored
        }

        let character = keyPress.characters.first ?? Character("\0")

        // Only handle single-char navigation keys, not regular typing
        // This prevents eating button/textfield input
        let navigationKeys: Set<Character> = ["j", "k", "g", "n", "p", "a", "r", "c", "d", "x", "y", "/"]
        guard character == "\u{1B}" /* escape */ || navigationKeys.contains(character) else {
            return .ignored
        }

        // 1. Escape always dismisses overlays
        if keyPress.key == .escape {
            return handleEscape()
        }

        // 2. Check chord tracker (g+t, g+b, etc.)
        if let action = chordTracker.handleKeyPress(character) {
            keyboardManager.handleAction(action, appState: appState)
            return .handled
        }

        // If chord is now pending (first key of a chord was pressed), consume the event
        if chordTracker.isChordActive {
            return .handled
        }

        // 3. Check context-specific bindings (j/k in list, review keys, etc.)
        let context = currentContext
        if let action = matchBinding(character: character, keyPress: keyPress, context: context) {
            keyboardManager.handleAction(action, appState: appState)
            return .handled
        }

        // 4. Check global non-modifier bindings
        if context != .global,
           let action = matchBinding(character: character, keyPress: keyPress, context: .global) {
            keyboardManager.handleAction(action, appState: appState)
            return .handled
        }

        return .ignored
    }

    private func handleEscape() -> KeyPress.Result {
        // Cancel active chord first
        if chordTracker.isChordActive {
            chordTracker.cancel()
            return .handled
        }

        // Dismiss command palette
        if appState.isCommandPaletteVisible {
            appState.toggleCommandPalette()
            return .handled
        }

        // Dismiss quick capture
        if appState.isQuickCaptureVisible {
            appState.toggleQuickCapture()
            return .handled
        }

        return .ignored
    }

    /// Maps the current app mode to a keybinding context.
    private var currentContext: KeybindingContext {
        switch appState.currentMode {
        case .review: .review
        case .agent: .agent
        case .editor: .editor
        // Modes that show list-based sidebars use list context
        case .intent, .ship, .database, .docs, .messaging, .notifications, .terminal:
            .list
        }
    }

    /// Finds a matching keybinding for the given character in the specified context.
    private func matchBinding(
        character: Character,
        keyPress: KeyPress,
        context: KeybindingContext
    ) -> String? {
        let bindings = AnvilKeybindings.bindings(for: context)
        // Only match bindings that have no modifiers (modifier shortcuts go through AnvilCommands)
        let match = bindings.first { binding in
            binding.modifiers == []
                && binding.key == KeyEquivalent(character)
        }
        return match?.action
    }
}

// MARK: - ChordIndicator

/// Displays a small pill at the bottom of the window showing the pending chord key,
/// e.g. "g → ?" to indicate the system is waiting for the second key.
struct ChordIndicator: View {
    let pendingKey: Character?

    var body: some View {
        if let key = pendingKey {
            HStack(spacing: 6) {
                Text(String(key))
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AnvilColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: 4))

                Text("→")
                    .foregroundStyle(AnvilColor.textSecondary)

                Text("?")
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AnvilColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 40)
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches the keyboard event router for non-modifier key handling.
    func keyEventRouter() -> some View {
        modifier(KeyEventRouter())
    }
}
