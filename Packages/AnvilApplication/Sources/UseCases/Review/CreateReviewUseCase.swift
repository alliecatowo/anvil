import AnvilDomain
import Foundation

/// Creates a new code review and persists it through ReviewManagementPort.
public struct CreateReviewUseCase: Sendable {
    private let reviewPort: any ReviewManagementPort
    private let eventBus: EventBus

    public init(reviewPort: any ReviewManagementPort, eventBus: EventBus) {
        self.reviewPort = reviewPort
        self.eventBus = eventBus
    }

    public func execute(
        title: String,
        sourceType: ReviewSourceType,
        sourceId: String,
        author: String
    ) async throws -> Review {
        let review = Review(
            title: title,
            sourceType: sourceType,
            sourceId: sourceId,
            author: author
        )
        let created = try await reviewPort.createReview(review)
        await eventBus.publish(AnyDomainEvent(
            sourcePrimitive: "review",
            payload: ["action": "created", "reviewId": created.id]
        ))
        return created
    }
}
