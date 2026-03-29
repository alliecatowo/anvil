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
        id: String? = nil,
        title: String,
        sourceType: ReviewSourceType,
        sourceId: String,
        author: String,
        diff: [FileDiff] = [],
        comments: [ReviewComment] = []
    ) async throws -> Review {
        let review = Review(
            id: id ?? UUID().uuidString,
            title: title,
            sourceType: sourceType,
            sourceId: sourceId,
            author: author,
            diff: diff,
            comments: comments
        )
        let created = try await reviewPort.createReview(review)
        await eventBus.publish(ReviewCreatedEvent(reviewId: created.id))
        return created
    }
}
