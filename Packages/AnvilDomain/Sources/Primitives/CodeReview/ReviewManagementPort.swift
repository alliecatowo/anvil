import Foundation

/// Port for managing the code review lifecycle (CRUD + status transitions).
/// Unlike `CodeReviewPort` (which targets external review providers like GitHub),
/// this port handles local review entity management within Anvil.
public protocol ReviewManagementPort: Sendable {
    func fetchReviews() async throws -> [Review]
    func createReview(_ review: Review) async throws -> Review
    func updateReview(_ review: Review) async throws -> Review
    func deleteReview(id: String) async throws
    func approveReview(id: String, comment: String?) async throws -> Review
    func requestChanges(id: String, comment: String) async throws -> Review
}
