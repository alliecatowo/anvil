import SwiftUI
import AnvilDomain
import AnvilGit
import Foundation

// DiffViewMode defined in DesignSystem/Components/AnvilDiffView.swift

// MARK: - Hunk Decision

enum HunkDecision: String {
    case pending, approved, rejected
}

// MARK: - Review View Model

@MainActor
public final class ReviewViewModel: ObservableObject {

    // MARK: Inbox

    @Published var reviews: [Review] = []
    @Published var selectedReviewID: String?
    @Published var selectedFileID: String?

    // MARK: Diff navigation

    @Published var diffViewMode: DiffViewMode = .sideBySide
    @Published var focusedHunkIndex: Int = 0
    @Published var hunkDecisions: [String: HunkDecision] = [:]

    // MARK: Branch diff (real git data)

    @Published var selectedBranchName: String?
    @Published var branchDiffFiles: [FileDiff] = []
    @Published var isLoadingBranchDiff: Bool = false

    // MARK: Blame

    @Published var isBlameVisible: Bool = false
    @Published var blameData: [Int: BlameLine] = [:]  // lineNumber -> BlameLine
    @Published var isLoadingBlame: Bool = false

    // MARK: Batch actions

    @Published var selectedReviewIDs: Set<String> = []

    // MARK: Computed

    var selectedReview: Review? {
        reviews.first { $0.id == selectedReviewID }
    }

    var selectedFile: FileDiff? {
        guard let review = selectedReview else { return nil }
        return review.diff.first { $0.id == selectedFileID }
    }

    var pendingReviews: [Review] {
        reviews.filter { $0.status == .pending }
    }

    var completedReviews: [Review] {
        reviews.filter { $0.status != .pending }
    }

    var currentHunks: [DiffHunk] {
        selectedFile?.hunks ?? []
    }

    // MARK: Init

    public init() {}

    // MARK: Navigation

    func selectReview(_ id: String) {
        selectedReviewID = id
        if let review = reviews.first(where: { $0.id == id }),
           let firstFile = review.diff.first {
            selectedFileID = firstFile.id
            focusedHunkIndex = 0
        }
    }

    func selectFile(_ id: String) {
        selectedFileID = id
        focusedHunkIndex = 0
    }

    func nextHunk() {
        if focusedHunkIndex < currentHunks.count - 1 {
            focusedHunkIndex += 1
        }
    }

    func previousHunk() {
        if focusedHunkIndex > 0 {
            focusedHunkIndex -= 1
        }
    }

    // MARK: Hunk decisions

    func approveHunk(_ hunkID: String) {
        hunkDecisions[hunkID] = .approved
    }

    func rejectHunk(_ hunkID: String) {
        hunkDecisions[hunkID] = .rejected
    }

    func decisionFor(_ hunkID: String) -> HunkDecision {
        hunkDecisions[hunkID] ?? .pending
    }

    // MARK: Batch

    func toggleSelection(_ id: String) {
        if selectedReviewIDs.contains(id) {
            selectedReviewIDs.remove(id)
        } else {
            selectedReviewIDs.insert(id)
        }
    }

    func approveSelected() {
        for i in reviews.indices where selectedReviewIDs.contains(reviews[i].id) {
            reviews[i].status = .approved
        }
        selectedReviewIDs.removeAll()
    }

    // MARK: - Branch Diff (real git)

    /// Load the diff of a branch against main/master using the git adapter.
    func loadBranchDiff(_ branchName: String, using adapter: GitSourceControlAdapter) {
        selectedBranchName = branchName
        isLoadingBranchDiff = true
        branchDiffFiles = []

        Task { @MainActor in
            defer { isLoadingBranchDiff = false }

            // Try diffing against main, fall back to master
            let baseBranch: String
            if let allBranches = try? await adapter.branches(),
               allBranches.contains(where: { $0.name == "main" }) {
                baseBranch = "main"
            } else {
                baseBranch = "master"
            }

            if let diffs = try? await adapter.diff(from: baseBranch, to: branchName) {
                branchDiffFiles = diffs

                // Auto-create a review entry so the existing DiffReviewView can display it
                let review = Review(
                    id: "branch-diff-\(branchName)",
                    title: "\(branchName) vs \(baseBranch)",
                    sourceType: .agentSession,
                    sourceId: branchName,
                    status: .pending,
                    author: "git",
                    diff: diffs,
                    comments: []
                )

                // Replace any existing branch-diff review
                reviews.removeAll { $0.id.hasPrefix("branch-diff-") }
                reviews.insert(review, at: 0)
                selectReview(review.id)
            }
        }
    }

    func clearBranchDiff() {
        selectedBranchName = nil
        branchDiffFiles = []
        reviews.removeAll { $0.id.hasPrefix("branch-diff-") }
        selectedReviewID = nil
        selectedFileID = nil
    }

    // MARK: - Blame

    func toggleBlame(using adapter: GitSourceControlAdapter) {
        isBlameVisible.toggle()
        if isBlameVisible {
            loadBlameForCurrentFile(using: adapter)
        } else {
            blameData = [:]
        }
    }

    func loadBlameForCurrentFile(using adapter: GitSourceControlAdapter) {
        guard isBlameVisible, let file = selectedFile else {
            blameData = [:]
            return
        }

        isLoadingBlame = true
        Task { @MainActor in
            defer { isLoadingBlame = false }
            if let lines = try? await adapter.blame(file: file.filePath, ref: nil) {
                var map: [Int: BlameLine] = [:]
                for line in lines {
                    map[line.lineNumber] = line
                }
                blameData = map
            }
        }
    }

    // MARK: - Sample Data (for previews only)

    #if DEBUG
    static func withSampleData() -> ReviewViewModel {
        let vm = ReviewViewModel()
        vm.reviews = makeSampleReviews()
        return vm
    }
    #endif

    static func makeSampleReviews() -> [Review] {
        let authHandlerDiff = FileDiff(
            filePath: "src/auth/handler.ts",
            status: .modified,
            hunks: [
                DiffHunk(
                    id: "hunk-auth-1",
                    oldStart: 43,
                    oldCount: 7,
                    newStart: 43,
                    newCount: 9,
                    header: "@@ -43,7 +43,9 @@ export class AuthHandler {",
                    lines: [
                        DiffLine(type: .context, content: "  async validateToken(token: JWTPayload) {", oldLineNumber: 43, newLineNumber: 43),
                        DiffLine(type: .context, content: "    const now = Date.now();", oldLineNumber: 44, newLineNumber: 44),
                        DiffLine(type: .removed, content: "    const exp = token.exp;", oldLineNumber: 45, newLineNumber: nil),
                        DiffLine(type: .added, content: "    const exp = token.exp", newLineNumber: 45),
                        DiffLine(type: .added, content: "      .toUTCString();", newLineNumber: 46),
                        DiffLine(type: .context, content: "    return exp > now;", oldLineNumber: 46, newLineNumber: 47),
                        DiffLine(type: .context, content: "  }", oldLineNumber: 47, newLineNumber: 48),
                    ]
                ),
                DiffHunk(
                    id: "hunk-auth-2",
                    oldStart: 72,
                    oldCount: 5,
                    newStart: 74,
                    newCount: 8,
                    header: "@@ -72,5 +74,8 @@ export class AuthHandler {",
                    lines: [
                        DiffLine(type: .context, content: "  async refreshSession(ctx: Context) {", oldLineNumber: 72, newLineNumber: 74),
                        DiffLine(type: .removed, content: "    return this.sessionService.refresh(ctx.userId);", oldLineNumber: 73, newLineNumber: nil),
                        DiffLine(type: .added, content: "    const session = await this.sessionService.refresh(ctx.userId);", newLineNumber: 75),
                        DiffLine(type: .added, content: "    this.metrics.increment('session.refresh');", newLineNumber: 76),
                        DiffLine(type: .added, content: "    return session;", newLineNumber: 77),
                        DiffLine(type: .context, content: "  }", oldLineNumber: 74, newLineNumber: 78),
                        DiffLine(type: .context, content: "}", oldLineNumber: 75, newLineNumber: 79),
                    ]
                ),
            ]
        )

        let configDiff = FileDiff(
            filePath: "src/config/database.ts",
            status: .modified,
            hunks: [
                DiffHunk(
                    id: "hunk-config-1",
                    oldStart: 10,
                    oldCount: 4,
                    newStart: 10,
                    newCount: 6,
                    header: "@@ -10,4 +10,6 @@ const dbConfig = {",
                    lines: [
                        DiffLine(type: .context, content: "  host: process.env.DB_HOST,", oldLineNumber: 10, newLineNumber: 10),
                        DiffLine(type: .context, content: "  port: 5432,", oldLineNumber: 11, newLineNumber: 11),
                        DiffLine(type: .removed, content: "  ssl: false,", oldLineNumber: 12, newLineNumber: nil),
                        DiffLine(type: .added, content: "  ssl: process.env.NODE_ENV === 'production',", newLineNumber: 12),
                        DiffLine(type: .added, content: "  connectionTimeout: 10_000,", newLineNumber: 13),
                        DiffLine(type: .context, content: "};", oldLineNumber: 13, newLineNumber: 14),
                    ]
                ),
            ]
        )

        let migrationDiff = FileDiff(
            filePath: "migrations/20260325_add_sessions_index.sql",
            status: .added,
            hunks: [
                DiffHunk(
                    id: "hunk-migration-1",
                    oldStart: 0,
                    oldCount: 0,
                    newStart: 1,
                    newCount: 5,
                    header: "@@ -0,0 +1,5 @@",
                    lines: [
                        DiffLine(type: .added, content: "-- Add index for session lookup performance", newLineNumber: 1),
                        DiffLine(type: .added, content: "CREATE INDEX CONCURRENTLY idx_sessions_user_id", newLineNumber: 2),
                        DiffLine(type: .added, content: "  ON sessions (user_id)", newLineNumber: 3),
                        DiffLine(type: .added, content: "  WHERE deleted_at IS NULL;", newLineNumber: 4),
                        DiffLine(type: .added, content: "", newLineNumber: 5),
                    ]
                ),
            ]
        )

        let review1 = Review(
            id: "review-1",
            title: "Fix token expiry validation & add metrics",
            sourceType: .pullRequest,
            sourceId: "pr-247",
            status: .pending,
            author: "danielk",
            diff: [authHandlerDiff, configDiff],
            comments: [
                ReviewComment(
                    author: "ci-bot",
                    body: "Coverage: 87.2% (+1.3%)",
                    isAIGenerated: true
                ),
            ]
        )

        let review2 = Review(
            id: "review-2",
            title: "Add sessions index migration",
            sourceType: .pullRequest,
            sourceId: "pr-251",
            status: .pending,
            author: "priya.s",
            diff: [migrationDiff],
            comments: []
        )

        let review3 = Review(
            id: "review-3",
            title: "Refactor user preferences module",
            sourceType: .agentSession,
            sourceId: "agent-session-12",
            status: .approved,
            author: "agent:claude",
            diff: [],
            comments: [
                ReviewComment(
                    author: "allie",
                    body: "LGTM, nice cleanup.",
                    isResolved: true
                ),
            ]
        )

        return [review1, review2, review3]
    }
}
