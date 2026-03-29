import AnvilDomain
import Foundation

/// Updates an existing review's status or content.
public struct UpdateReviewUseCase: Sendable {
    private let reviewPort: any ReviewManagementPort
    private let eventBus: EventBus

    public init(reviewPort: any ReviewManagementPort, eventBus: EventBus) {
        self.reviewPort = reviewPort
        self.eventBus = eventBus
    }

    public func execute(review: Review) async throws -> Review {
        let updated = try await reviewPort.updateReview(review)
        await eventBus.publish(ReviewUpdatedEvent(reviewId: updated.id, status: updated.status.rawValue))
        return updated
    }
}
