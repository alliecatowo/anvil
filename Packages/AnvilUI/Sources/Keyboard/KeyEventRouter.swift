import SwiftUI
import AppKit

// MARK: - KeyEventRouter

/// View modifier that routes non-modifier key events through the chord tracker and
/// context-specific keybindings before falling back to global bindings.
/// Modifier-based shortcuts (Cmd-1, Cmd-K, etc.) are handled by AnvilCommands menu items.
///
/// Uses NSEvent.addLocalMonitorForEvents instead of SwiftUI's .onKeyPress to avoid
/// intercepting key events destined for text fields. The AppKit event monitor fires
/// with accurate first-responder information, so we can reliably detect when the
/// user is typing in a text field and pass those events through untouched.
struct KeyEventRouter: ViewModifier {
    @EnvironmentObject var appState: AppState
    @StateObject private var chordTracker = ChordTracker()
    @StateObject private var keyboardManager = KeyboardManager()
    @StateObject private var eventMonitor = KeyEventMonitor()

    func body(content: Content) -> some View {
        content
            .environmentObject(keyboardManager)
            .environmentObject(chordTracker)
            .onAppear {
                eventMonitor.install(
                    appState: appState,
                    chordTracker: chordTracker,
                    keyboardManager: keyboardManager
                )
            }
            .onDisappear {
                eventMonitor.uninstall()
            }
            .onChange(of: appState.currentMode) { _, _ in
                // Keep the monitor's reference to appState fresh
                eventMonitor.install(
                    appState: appState,
                    chordTracker: chordTracker,
                    keyboardManager: keyboardManager
                )
            }
            .overlay(alignment: .bottom) {
                if chordTracker.isChordActive {
                    ChordIndicator(pendingKey: chordTracker.pendingKey)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(AnvilAnimation.standard, value: chordTracker.isChordActive)
    }
}

// MARK: - KeyEventMonitor

/// Manages an NSEvent local monitor for key-down events. By using AppKit's event
/// pipeline directly, we get accurate first-responder detection. When a text field
/// (NSTextView or NSTextField) is the first responder, events pass through untouched
/// so the user can type normally.
@MainActor
final class KeyEventMonitor: ObservableObject {
    private var monitor: Any?
    private weak var appState: AppState?
    private weak var chordTracker: ChordTracker?
    private weak var keyboardManager: KeyboardManager?

    func install(appState: AppState, chordTracker: ChordTracker, keyboardManager: KeyboardManager) {
        self.appState = appState
        self.chordTracker = chordTracker
        self.keyboardManager = keyboardManager

        // Only install once -- repeated calls just update the weak references
        guard monitor == nil else { return }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Local event monitors always fire on the main thread, so we can
            // safely access MainActor-isolated state. We extract event properties
            // here (outside any isolation boundary) and route into our nonisolated
            // trampoline which uses MainActor.assumeIsolated internally.
            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
            let characters = event.charactersIgnoringModifiers ?? ""
            guard let self else { return event }

            let consumed = self.routeKeyEvent(
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                characters: characters
            )
            return consumed ? nil : event
        }
    }

    func uninstall() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    // Note: no deinit needed. The monitor is removed via uninstall() called from
    // onDisappear. Swift 6 strict concurrency prevents accessing non-Sendable
    // stored properties (Any?) from a nonisolated deinit.

    // MARK: - Nonisolated Trampoline

    /// Nonisolated entry point callable from the NSEvent monitor closure.
    /// AppKit local event monitors always fire on the main thread, so
    /// MainActor.assumeIsolated is safe here. This avoids the Swift 6
    /// strict-concurrency error where a nonisolated closure cannot see
    /// members of a @MainActor-isolated type.
    nonisolated func routeKeyEvent(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        characters: String
    ) -> Bool {
        MainActor.assumeIsolated {
            self.handleKeyData(
                keyCode: keyCode,
                modifierFlags: modifierFlags,
                characters: characters
            )
        }
    }

    // MARK: - First Responder Detection

    /// Returns true when a text input has first responder, meaning the user is typing.
    /// At this point in the AppKit event pipeline, the first responder is already set
    /// correctly, unlike in SwiftUI's .onKeyPress which fires too early.
    ///
    /// We check for:
    /// - NSTextView: backs SwiftUI TextField, TextEditor, and NSTextField's field editor
    /// - NSTextField: direct AppKit text fields
    /// - SwiftUI internal text input views (by class name as a safety net)
    private var isTextFieldFocused: Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else {
            return false
        }
        // NSTextView is the field editor used by NSTextField and also backs
        // SwiftUI's TextField and TextEditor. This is the most reliable check.
        if firstResponder is NSTextView {
            return true
        }
        if firstResponder is NSTextField {
            return true
        }
        // Safety net: check class name for any SwiftUI-internal text input views
        let className = String(describing: type(of: firstResponder))
        if className.contains("TextInput") || className.contains("FieldEditor") {
            return true
        }
        return false
    }

    // MARK: - Key Routing

    /// Returns true if the event was consumed and should not be forwarded.
    private func handleKeyData(
        keyCode: UInt16,
        modifierFlags: NSEvent.ModifierFlags,
        characters _: String
    ) -> Bool {
        guard let appState, let chordTracker else {
            return false
        }

        // Skip when modifier keys are held -- those are handled by AnvilCommands
        let flags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasModifiers = flags.contains(.command)
            || flags.contains(.control)
            || flags.contains(.option)
        if hasModifiers { return false }

        // Skip when command palette, quick capture, or any overlay is active
        if appState.isCommandPaletteVisible || appState.isQuickCaptureVisible || appState.isCodebaseQAVisible {
            return false
        }

        // 1. Escape always dismisses overlays (check before text field guard)
        if keyCode == 53 { // 53 = Escape key code
            return handleEscape(appState: appState, chordTracker: chordTracker)
        }

        // NUCLEAR FIX: Never consume bare character keys. Period.
        // Chords (g→b), j/k navigation, and all bare-key shortcuts are DISABLED
        // until we can guarantee they never interfere with text input.
        // All shortcuts must use modifier keys (⌘, ⌃, ⌥) via AnvilCommands.
        return false
    }

    private func handleEscape(appState: AppState, chordTracker: ChordTracker) -> Bool {
        // Cancel active chord first
        if chordTracker.isChordActive {
            chordTracker.cancel()
            return true
        }

        // Dismiss command palette
        if appState.isCommandPaletteVisible {
            appState.toggleCommandPalette()
            return true
        }

        // Dismiss quick capture
        if appState.isQuickCaptureVisible {
            appState.toggleQuickCapture()
            return true
        }

        // Dismiss codebase Q&A
        if appState.isCodebaseQAVisible {
            appState.toggleCodebaseQA()
            return true
        }

        // Dismiss project search
        if appState.isProjectSearchVisible {
            appState.toggleProjectSearch()
            return true
        }

        return false
    }

    /// Maps the current app mode to a keybinding context.
    private func currentContext(appState: AppState) -> KeybindingContext {
        switch appState.currentMode {
        case .review: .review
        case .agent: .agent
        case .editor: .editor
        case .intent, .ship, .database, .docs, .messaging, .notifications, .terminal, .testing, .extensions:
            .list
        }
    }

    /// Finds a matching keybinding for the given character in the specified context.
    private func matchBinding(
        character: Character,
        context: KeybindingContext
    ) -> String? {
        let bindings = AnvilKeybindings.bindings(for: context)
        let match = bindings.first { binding in
            binding.modifiers == []
                && binding.key == KeyEquivalent(character)
        }
        return match?.action
    }
}

// MARK: - ChordIndicator

/// Displays a small pill at the bottom of the window showing the pending chord key,
/// e.g. "g -> ?" to indicate the system is waiting for the second key.
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

                Text("\u{2192}")
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
