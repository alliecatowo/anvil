import Foundation

/// Descriptor for a command in the unified command registry.
/// Pure domain type with no UI dependencies.
public struct AnvilCommand: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let icon: String
    public let category: CommandCategory
    public let keyboardShortcut: String?
    /// Space scoping: if non-nil, command only appears when this space is active.
    /// Uses AnvilSpace raw values (e.g., "Plan", "Build", "Review", "Operate", "Library").
    public let spaceScope: String?
    /// Group for prefix-based filtering (e.g., "Git", "Terminal", "Editor").
    public let group: String?
    /// Entity type scoping: if non-nil, command only appears when this entity type is focused.
    /// Uses FocusedEntityType raw values (e.g., "ticket", "file", "agentSession", "pullRequest").
    public let entityType: String?
    /// Structured key binding for this command.
    /// The UI layer converts this to SwiftUI `KeyEquivalent` + `EventModifiers`.
    public let keyBinding: KeyBinding?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String,
        category: CommandCategory,
        keyboardShortcut: String? = nil,
        spaceScope: String? = nil,
        group: String? = nil,
        entityType: String? = nil,
        keyBinding: KeyBinding? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.category = category
        self.keyboardShortcut = keyboardShortcut
        self.spaceScope = spaceScope
        self.group = group
        self.entityType = entityType
        self.keyBinding = keyBinding
    }
}

/// Entity types that can receive contextual commands.
public enum FocusedEntityType: String, CaseIterable, Sendable {
    case ticket
    case file
    case agentSession
    case pullRequest
}

/// Categories for organizing commands in the palette.
public enum CommandCategory: String, CaseIterable, Sendable {
    case navigation = "Navigation"
    case agent = "Agent"
    case plan = "Plan"
    case review = "Review"
    case operate = "Operate"
    case editor = "Editor"
    case terminal = "Terminal"
    case view = "View"
    case actions = "Actions"
    case spaces = "Spaces"
}
