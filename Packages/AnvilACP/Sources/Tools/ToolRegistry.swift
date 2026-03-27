import Foundation
import AnvilDomain

public actor ToolRegistry {
    private var tools: [String: ACPToolDefinition] = [:]

    public init() {}

    public func register(_ tool: ACPToolDefinition) {
        tools[tool.name] = tool
    }

    public func unregister(_ name: String) {
        tools.removeValue(forKey: name)
    }

    public func tool(_ name: String) -> ACPToolDefinition? {
        tools[name]
    }

    public func allTools() -> [ACPToolDefinition] {
        Array(tools.values)
    }

    public func tools(matching names: [String]) -> [ACPToolDefinition] {
        names.compactMap { tools[$0] }
    }
}
