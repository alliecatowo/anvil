import Foundation

public actor ProviderRegistry {
    public static let shared = ProviderRegistry()

    private var providers: [String: [String: any AnvilProviderDefinition]] = [:] // [primitiveId: [providerId: provider]]

    private init() {}

    public func register(_ provider: any AnvilProviderDefinition, for primitiveId: String) {
        var list = providers[primitiveId] ?? [:]
        list[provider.providerId] = provider
        providers[primitiveId] = list
    }

    public func providers(for primitiveId: String) -> [any AnvilProviderDefinition] {
        guard let dict = providers[primitiveId] else { return [] }
        return Array(dict.values)
    }

    public func provider(id: String, for primitiveId: String) -> (any AnvilProviderDefinition)? {
        providers[primitiveId]?[id]
    }
}
