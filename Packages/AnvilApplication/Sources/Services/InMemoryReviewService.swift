import AnvilDomain
import Foundation

/// In-memory review store — default implementation until a real backend is wired.
public actor InMemoryReviewService: ReviewManagementPort {
    private var reviews: [String: Review] = [:]

    public init() {}

    public func fetchReviews() async throws -> [Review] {
        Array(reviews.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func createReview(_ review: Review) async throws -> Review {
        reviews[review.id] = review
        return review
    }

    public func updateReview(_ review: Review) async throws -> Review {
        guard reviews[review.id] != nil else { throw ReviewServiceError.notFound }
        reviews[review.id] = review
        return review
    }

    public func deleteReview(id: String) async throws {
        reviews.removeValue(forKey: id)
    }

    public func approveReview(id: String, comment: String?) async throws -> Review {
        guard let existing = reviews[id] else { throw ReviewServiceError.notFound }
        let updated = Review(
            id: existing.id,
            title: existing.title,
            sourceType: existing.sourceType,
            sourceId: existing.sourceId,
            status: .approved,
            reviewer: existing.reviewer,
            author: existing.author,
            diff: existing.diff,
            comments: existing.comments,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        reviews[id] = updated
        return updated
    }

    public func requestChanges(id: String, comment: String) async throws -> Review {
        guard let existing = reviews[id] else { throw ReviewServiceError.notFound }
        let updated = Review(
            id: existing.id,
            title: existing.title,
            sourceType: existing.sourceType,
            sourceId: existing.sourceId,
            status: .changesRequested,
            reviewer: existing.reviewer,
            author: existing.author,
            diff: existing.diff,
            comments: existing.comments,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        reviews[id] = updated
        return updated
    }
}

public enum ReviewServiceError: Error, Sendable {
    case notFound
}
