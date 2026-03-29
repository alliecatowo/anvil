import Foundation
import AnvilDomain

/// Central registry for all commands in Anvil.
/// Single source of truth: both the menu bar (AnvilCommands) and command palette
/// query this registry. Context-sensitive filtering by active space.
///
/// The registry stores command descriptors (AnvilCommand) and action identifiers.
/// Action execution is handled by the UI layer (CommandAction.perform on AppState).
@MainActor
public final class CommandRegistry: ObservableObject {

    /// All registered commands.
    @Published public private(set) var commands: [AnvilCommand] = []

    /// Command ID -> handler closure. UI layer registers handlers.
    private var handlers: [String: @MainActor () -> Void] = [:]

    public init() {}

    // MARK: - Registration

    /// Register a command with an action handler.
    public func register(_ command: AnvilCommand, handler: @escaping @MainActor () -> Void) {
        // Replace if ID already exists
        commands.removeAll { $0.id == command.id }
        commands.append(command)
        handlers[command.id] = handler
    }

    /// Register multiple commands with a shared handler lookup.
    public func register(_ batch: [(command: AnvilCommand, handler: @MainActor () -> Void)]) {
        for (command, handler) in batch {
            register(command, handler: handler)
        }
    }

    /// Remove a command by ID.
    public func unregister(id: String) {
        commands.removeAll { $0.id == id }
        handlers.removeValue(forKey: id)
    }

    // MARK: - Queries

    /// All commands visible in the given space (global + space-scoped).
    public func commands(forSpace space: String?) -> [AnvilCommand] {
        commands.filter { cmd in
            cmd.spaceScope == nil || cmd.spaceScope == space
        }
    }

    /// Commands in a specific category, optionally filtered by space.
    public func commands(category: CommandCategory, space: String? = nil) -> [AnvilCommand] {
        commands(forSpace: space).filter { $0.category == category }
    }

    /// Commands matching a group prefix (e.g., "Git", "Terminal").
    public func commands(group: String, space: String? = nil) -> [AnvilCommand] {
        commands(forSpace: space).filter { $0.group == group }
    }

    /// Commands scoped to a specific entity type, optionally filtered by space.
    /// Returns commands where entityType matches, plus commands with no entityType (global).
    public func commands(forEntityType entityType: String?, space: String? = nil) -> [AnvilCommand] {
        let spaceFiltered = commands(forSpace: space)
        guard let entityType else { return spaceFiltered.filter { $0.entityType == nil } }
        return spaceFiltered.filter { $0.entityType == nil || $0.entityType == entityType }
    }

    /// Look up a single command by ID.
    public func command(id: String) -> AnvilCommand? {
        commands.first { $0.id == id }
    }

    // MARK: - Execution

    /// Execute a command's handler by ID. Returns true if the command was found and executed.
    @discardableResult
    public func execute(id: String) -> Bool {
        guard let handler = handlers[id] else { return false }
        handler()
        return true
    }
}
