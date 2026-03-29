import Foundation

/// A keyboard shortcut binding — pure domain type with no SwiftUI dependency.
/// The UI layer converts this to `KeyEquivalent` + `EventModifiers`.
public struct KeyBinding: Sendable, Codable, Equatable {
    /// The key character (e.g. "k", "f", "/", "w") or named key (e.g. "f12", "escape", "return", "delete").
    public let key: String
    /// Modifier keys required for this binding.
    public let modifiers: Set<Modifier>

    public init(key: String, modifiers: Set<Modifier> = []) {
        self.key = key
        self.modifiers = modifiers
    }

    /// Convenience initializers for common patterns.
    public static func cmd(_ key: String) -> KeyBinding {
        KeyBinding(key: key, modifiers: [.command])
    }

    public static func cmdShift(_ key: String) -> KeyBinding {
        KeyBinding(key: key, modifiers: [.command, .shift])
    }

    public static func cmdOption(_ key: String) -> KeyBinding {
        KeyBinding(key: key, modifiers: [.command, .option])
    }

    /// Modifier key identifiers.
    public enum Modifier: String, Sendable, Codable, CaseIterable {
        case command
        case shift
        case option
        case control
    }

    /// Human-readable display string (e.g. "Cmd+Shift+F").
    public var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("\u{2303}") }
        if modifiers.contains(.option) { parts.append("\u{2325}") }
        if modifiers.contains(.shift) { parts.append("\u{21E7}") }
        if modifiers.contains(.command) { parts.append("\u{2318}") }
        parts.append(key.count == 1 ? key.uppercased() : key)
        return parts.joined()
    }
}
