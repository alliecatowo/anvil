import SwiftUI
import AnvilDomain

struct ReviewInboxView: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Review Inbox")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Text("\(viewModel.pendingReviews.count) pending")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.md)

            Divider().overlay(AnvilColor.borderSubtle)

            // Batch action bar
            if !viewModel.selectedReviewIDs.isEmpty {
                batchActionBar
                Divider().overlay(AnvilColor.borderSubtle)
            }

            // List
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !viewModel.pendingReviews.isEmpty {
                        sectionHeader("Needs Review")
                        ForEach(viewModel.pendingReviews) { review in
                            reviewRow(review)
                            Divider().overlay(AnvilColor.borderSubtle)
                        }
                    }

                    if !viewModel.completedReviews.isEmpty {
                        sectionHeader("Completed")
                        ForEach(viewModel.completedReviews) { review in
                            reviewRow(review)
                            Divider().overlay(AnvilColor.borderSubtle)
                        }
                    }
                }
            }

            // Keyboard hint bar
            HStack(spacing: AnvilSpacing.lg) {
                keyHint("j", "next")
                keyHint("k", "prev")
                keyHint("enter", "open")
                keyHint("x", "select")
                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)
        }
    }

    // MARK: - Subviews

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)
            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
    }

    private func reviewRow(_ review: Review) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Selection checkbox
            Image(systemName: viewModel.selectedReviewIDs.contains(review.id) ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(
                    viewModel.selectedReviewIDs.contains(review.id)
                        ? AnvilColor.accentBlue
                        : AnvilColor.textTertiary
                )
                .onTapGesture { viewModel.toggleSelection(review.id) }

            // Status indicator
            statusIcon(for: review.status)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                HStack {
                    Text(review.title)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    AnvilBadge(
                        text: review.sourceId,
                        color: review.sourceType == .pullRequest
                            ? AnvilColor.accentBlue
                            : AnvilColor.accentPurple
                    )
                }

                HStack(spacing: AnvilSpacing.sm) {
                    Text(review.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)

                    Text("\(review.diff.count) file\(review.diff.count == 1 ? "" : "s")")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    if !review.comments.isEmpty {
                        HStack(spacing: AnvilSpacing.xxxs) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 10))
                            Text("\(review.comments.count)")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(
            viewModel.selectedReviewID == review.id
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectReview(review.id) }
    }

    private var batchActionBar: some View {
        HStack(spacing: AnvilSpacing.md) {
            Text("\(viewModel.selectedReviewIDs.count) selected")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            AnvilButton("Approve All", icon: "checkmark", style: .primary) {
                viewModel.approveSelected()
            }

            AnvilButton("Clear", style: .ghost) {
                viewModel.selectedReviewIDs.removeAll()
            }
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
    }

    private func statusIcon(for status: ReviewStatus) -> some View {
        let (icon, color): (String, Color) = switch status {
        case .pending: ("circle", AnvilColor.accentAmber)
        case .approved: ("checkmark.circle.fill", AnvilColor.accentGreen)
        case .changesRequested: ("exclamationmark.circle.fill", AnvilColor.accentRed)
        case .dismissed: ("minus.circle", AnvilColor.textTertiary)
        }
        return Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundStyle(color)
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: AnvilSpacing.xxxs) {
            Text(key)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(AnvilColor.backgroundElevated)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(AnvilColor.borderMedium, lineWidth: 1)
                )
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }
}
