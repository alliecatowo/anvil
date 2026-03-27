import Foundation

public actor PluginManager {
    public struct PluginInfo: Sendable {
        public let id: String
        public let name: String
        public let version: String
        public let isActive: Bool

        public init(id: String, name: String, version: String, isActive: Bool = true) {
            self.id = id
            self.name = name
            self.version = version
            self.isActive = isActive
        }
    }

    private var plugins: [String: PluginInfo] = [:]

    public init() {}

    public func register(_ plugin: PluginInfo) {
        plugins[plugin.id] = plugin
    }

    public func unregister(_ pluginId: String) {
        plugins.removeValue(forKey: pluginId)
    }

    public func allPlugins() -> [PluginInfo] {
        Array(plugins.values)
    }

    public func plugin(_ id: String) -> PluginInfo? {
        plugins[id]
    }
}
