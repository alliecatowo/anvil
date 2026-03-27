import Foundation

/// Defines the contract a provider must fulfill for a given primitive.
/// Used by plugins that introduce new primitives.
public protocol PrimitiveContract: Sendable {
    /// Unique identifier for this primitive type
    static var primitiveId: String { get }

    /// Human-readable name
    static var displayName: String { get }

    /// SF Symbol icon name
    static var iconName: String { get }

    /// Required capabilities that any provider must implement
    static var requiredCapabilities: [String] { get }
}
