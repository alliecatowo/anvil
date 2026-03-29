import SwiftUI
import AnvilDomain

/// Bridges domain-layer `KeyBinding` to SwiftUI `KeyEquivalent` and `EventModifiers`.
extension KeyBinding {
    /// Convert to SwiftUI `EventModifiers`.
    public var swiftUIModifiers: EventModifiers {
        var result: EventModifiers = []
        if modifiers.contains(.command) { result.insert(.command) }
        if modifiers.contains(.shift) { result.insert(.shift) }
        if modifiers.contains(.option) { result.insert(.option) }
        if modifiers.contains(.control) { result.insert(.control) }
        return result
    }

    /// Convert to SwiftUI `KeyEquivalent`.
    /// Returns nil for unrecognized named keys.
    public var swiftUIKey: KeyEquivalent? {
        if key.count == 1, let char = key.first {
            return KeyEquivalent(char)
        }
        switch key.lowercased() {
        case "return", "enter": return .return
        case "escape", "esc": return .escape
        case "delete", "backspace": return .delete
        case "tab": return .tab
        case "space": return .space
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        case "f1": return KeyEquivalent(Character(UnicodeScalar(NSF1FunctionKey)!))
        case "f2": return KeyEquivalent(Character(UnicodeScalar(NSF2FunctionKey)!))
        case "f3": return KeyEquivalent(Character(UnicodeScalar(NSF3FunctionKey)!))
        case "f4": return KeyEquivalent(Character(UnicodeScalar(NSF4FunctionKey)!))
        case "f5": return KeyEquivalent(Character(UnicodeScalar(NSF5FunctionKey)!))
        case "f6": return KeyEquivalent(Character(UnicodeScalar(NSF6FunctionKey)!))
        case "f7": return KeyEquivalent(Character(UnicodeScalar(NSF7FunctionKey)!))
        case "f8": return KeyEquivalent(Character(UnicodeScalar(NSF8FunctionKey)!))
        case "f9": return KeyEquivalent(Character(UnicodeScalar(NSF9FunctionKey)!))
        case "f10": return KeyEquivalent(Character(UnicodeScalar(NSF10FunctionKey)!))
        case "f11": return KeyEquivalent(Character(UnicodeScalar(NSF11FunctionKey)!))
        case "f12": return KeyEquivalent(Character(UnicodeScalar(NSF12FunctionKey)!))
        default: return nil
        }
    }
}

/// View modifier that applies a `KeyBinding` as a `.keyboardShortcut`.
extension View {
    /// Apply a domain `KeyBinding` as a native SwiftUI keyboard shortcut.
    @ViewBuilder
    public func keyBinding(_ binding: KeyBinding?) -> some View {
        if let binding, let key = binding.swiftUIKey {
            self.keyboardShortcut(key, modifiers: binding.swiftUIModifiers)
        } else {
            self
        }
    }
}
