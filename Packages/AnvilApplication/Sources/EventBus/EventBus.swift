import Foundation
import AnvilDomain

public actor EventBus {
    public static let shared = EventBus()

    public typealias EventHandler = @Sendable (any AnvilDomainEvent) async -> Void

    private var handlers: [String: [EventHandler]] = [:]

    private init() {}

    public func subscribe(to eventType: String, handler: @escaping EventHandler) {
        var list = handlers[eventType] ?? []
        list.append(handler)
        handlers[eventType] = list
    }

    public func publish(_ event: any AnvilDomainEvent) async {
        let eventType = String(describing: type(of: event))
        if let eventHandlers = handlers[eventType] {
            for handler in eventHandlers {
                await handler(event)
            }
        }
        // Also notify wildcard listeners
        if let wildcardHandlers = handlers["*"] {
            for handler in wildcardHandlers {
                await handler(event)
            }
        }
    }
}
