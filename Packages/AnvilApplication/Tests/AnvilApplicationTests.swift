import XCTest
@testable import AnvilApplication
import AnvilDomain

final class AnvilApplicationTests: XCTestCase {
    func testEventBusPublishAndSubscribe() async {
        let bus = EventBus.shared
        var received = false

        await bus.subscribe(to: "*") { _ in
            received = true
        }

        await bus.publish(AnyDomainEvent(sourcePrimitive: "test", payload: "hello"))
        XCTAssertTrue(received)
    }

    func testACPRouterRegistration() async {
        let router = ACPRouter()
        let config = ACPRouter.RouteConfig(
            taskType: .codeGeneration,
            primaryProvider: "anthropic",
            primaryModel: "claude-opus-4-6"
        )
        await router.setRoute(config)
        let route = await router.route(for: .codeGeneration)
        XCTAssertEqual(route?.primaryProvider, "anthropic")
    }

    func testNotificationAggregator() async {
        let aggregator = NotificationAggregator()
        await aggregator.add(.init(sourcePrimitive: "test", title: "Test", body: "body"))
        let count = await aggregator.unreadCount()
        XCTAssertEqual(count, 1)
    }
}
