import Foundation

public actor PrimitiveRegistry {
    public static let shared = PrimitiveRegistry()

    private var primitives: [String: any AnvilPrimitiveDefinition] = [:]

    private init() {}

    public func register(_ primitive: any AnvilPrimitiveDefinition) {
        primitives[type(of: primitive).primitiveId] = primitive
    }

    public func primitive(for id: String) -> (any AnvilPrimitiveDefinition)? {
        primitives[id]
    }

    public func allPrimitives() -> [any AnvilPrimitiveDefinition] {
        Array(primitives.values)
    }
}
