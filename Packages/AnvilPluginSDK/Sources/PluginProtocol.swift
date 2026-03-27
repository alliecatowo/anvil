import Foundation
import AnvilDomain

// MARK: - Plugin Protocol

/// Base protocol that all Anvil plugins implement.
public protocol AnvilPlugin: Sendable {
    static var metadata: PluginMetadata { get }

    /// Called when the plugin is loaded. Set up providers, register views, etc.
    func activate(context: PluginContext) async throws

    /// Called when the plugin is unloaded. Clean up resources.
    func deactivate() async
}

// MARK: - Plugin Metadata

public struct PluginMetadata: Sendable {
    public let id: String
    public let name: String
    public let version: String
    public let pluginDescription: String
    public let author: String
    public let provides: [ProviderDeclaration]
    public let introduces: [PrimitiveDeclaration]
    public let requires: [PrimitiveRequirement]
    public let views: [ViewDeclaration]
    public let commands: [CommandDeclaration]

    public init(
        id: String,
        name: String,
        version: String,
        pluginDescription: String = "",
        author: String = "",
        provides: [ProviderDeclaration] = [],
        introduces: [PrimitiveDeclaration] = [],
        requires: [PrimitiveRequirement] = [],
        views: [ViewDeclaration] = [],
        commands: [CommandDeclaration] = []
    ) {
        self.id = id
        self.name = name
        self.version = version
        self.pluginDescription = pluginDescription
        self.author = author
        self.provides = provides
        self.introduces = introduces
        self.requires = requires
        self.views = views
        self.commands = commands
    }
}

// MARK: - Declarations

public struct ProviderDeclaration: Sendable {
    public let primitiveId: String
    public let providerId: String

    public init(for primitiveId: String, id providerId: String) {
        self.primitiveId = primitiveId
        self.providerId = providerId
    }

    public static func provider(for primitiveId: String, id: String) -> ProviderDeclaration {
        ProviderDeclaration(for: primitiveId, id: id)
    }
}

public struct PrimitiveDeclaration: Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    public static func primitive(id: String, name: String) -> PrimitiveDeclaration {
        PrimitiveDeclaration(id: id, name: name)
    }
}

public struct PrimitiveRequirement: Sendable {
    public let primitiveId: String

    public init(_ primitiveId: String) {
        self.primitiveId = primitiveId
    }

    public static func primitive(_ id: String) -> PrimitiveRequirement {
        PrimitiveRequirement(id)
    }
}

public enum ViewLocation: String, Sendable {
    case sidebarSection
    case mainView
    case inlineAnnotation
    case inspectorPanel
    case statusBarItem
}

public struct ViewDeclaration: Sendable {
    public let location: ViewLocation
    public let id: String
    public let mode: String?

    public init(location: ViewLocation, id: String, mode: String? = nil) {
        self.location = location
        self.id = id
        self.mode = mode
    }

    public static func sidebarSection(mode: String, id: String) -> ViewDeclaration {
        ViewDeclaration(location: .sidebarSection, id: id, mode: mode)
    }

    public static func mainView(id: String) -> ViewDeclaration {
        ViewDeclaration(location: .mainView, id: id)
    }

    public static func inlineAnnotation(id: String) -> ViewDeclaration {
        ViewDeclaration(location: .inlineAnnotation, id: id)
    }
}

public struct CommandDeclaration: Sendable {
    public let id: String
    public let title: String
    public let shortcut: String?

    public init(id: String, title: String, shortcut: String? = nil) {
        self.id = id
        self.title = title
        self.shortcut = shortcut
    }

    public static func command(id: String, title: String, shortcut: String? = nil) -> CommandDeclaration {
        CommandDeclaration(id: id, title: title, shortcut: shortcut)
    }
}

// MARK: - Plugin Context

/// The context provided to plugins during activation. Gives access to Anvil's systems.
public protocol PluginContext: Sendable {
    /// Access ACP for AI completions — no API key needed
    func complete(prompt: String, systemPrompt: String?, taskType: String?) async throws -> String

    /// Plugin-scoped persistent storage
    func storageGet<T: Codable & Sendable>(_ key: String) async throws -> T?
    func storageSet<T: Codable & Sendable>(_ key: String, value: T) async throws
    func storageDelete(_ key: String) async throws

    /// Request data from other primitives
    func requestFromPrimitive(_ primitiveId: String, action: String, parameters: [String: String]) async throws -> String
}
