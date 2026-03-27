import Foundation

public protocol AnvilPrimitiveDefinition: Sendable {
    static var primitiveId: String { get }
    static var displayName: String { get }
    static var iconName: String { get }
}

public protocol AnvilProviderDefinition: Sendable {
    var providerId: String { get }
    var providerName: String { get }
    func validateConnection() async throws -> Bool
}
