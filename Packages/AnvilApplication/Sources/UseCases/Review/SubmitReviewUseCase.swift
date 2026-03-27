import Foundation
import AnvilDomain

public struct SubmitReviewUseCase: Sendable {
    public init() {}

    public func execute(
        reviewId: String,
        status: ReviewStatus,
        comments: [ReviewCommentDraft],
        provider: any CodeReviewPort
    ) async throws {
        try await provider.submitReview(id: reviewId, status: status, comments: comments)
    }
}
