import Foundation

public protocol CodeReviewPort: AnvilProviderDefinition {
    func pendingReviews() async throws -> [Review]
    func reviewDetail(id: String) async throws -> Review
    func submitReview(id: String, status: ReviewStatus, comments: [ReviewCommentDraft]) async throws
    func resolveComment(id: String) async throws
    func requestReview(from: String, for reviewId: String) async throws
}
