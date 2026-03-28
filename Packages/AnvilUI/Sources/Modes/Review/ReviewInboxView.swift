import SwiftUI
import AnvilDomain

struct ReviewInboxView: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Review Inbox")
                    .font(AnvilFont.heading)

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.md)
            .background(.bar)

            if !viewModel.selectedReviewIDs.isEmpty {
                batchActionBar
                Divider()
            }

            List {
                if !viewModel.pendingReviews.isEmpty {
                    Section("Needs Review") {
                        ForEach(viewModel.pendingReviews) { review in
                            reviewRow(review)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }

                if !viewModel.completedReviews.isEmpty {
                    Section("Completed") {
                        ForEach(viewModel.completedReviews) { review in
                            reviewRow(review)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Subviews

    private func reviewRow(_ review: Review) -> some View {
        Button {
            viewModel.selectReview(review.id)
        } label: {
            HStack(spacing: AnvilSpacing.md) {
                Toggle("", isOn: Binding(
                    get: { viewModel.selectedReviewIDs.contains(review.id) },
                    set: { _ in viewModel.toggleSelection(review.id) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .frame(width: 18)
                .accessibilityLabel("Select \(review.title)")
                .accessibilityAddTraits(.isToggle)

                statusIcon(for: review.status)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                    HStack {
                        Text(review.title)
                            .font(AnvilFont.body)
                            .lineLimit(1)

                        Spacer()

                        Text(review.sourceId)
                            .font(AnvilFont.label)
                            .foregroundStyle(review.sourceType == .pullRequest ? .blue : .purple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: AnvilSpacing.sm) {
                        Text(review.author)
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)

                        Text("\(review.diff.count) file\(review.diff.count == 1 ? "" : "s")")
                            .font(AnvilFont.label)
                            .foregroundStyle(.secondary)

                        if !review.comments.isEmpty {
                            HStack(spacing: AnvilSpacing.xxxs) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 10))
                                    .accessibilityHidden(true)
                                Text("\(review.comments.count)")
                                    .font(AnvilFont.label)
                            }
                            .foregroundStyle(.secondary)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(review.comments.count) comments")
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .background(viewModel.selectedReviewID == review.id ? Color.accentColor.opacity(0.14) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(review.title), by \(review.author), \(review.sourceId), \(review.diff.count) files, status \(String(describing: review.status))")
        .accessibilityAddTraits(.isButton)
    }

    private var batchActionBar: some View {
        HStack(spacing: AnvilSpacing.md) {
            Text("\(viewModel.selectedReviewIDs.count) selected")
                .font(AnvilFont.label)
                .foregroundStyle(.secondary)

            Spacer()

            AnvilButton("Approve All", icon: "checkmark", style: .primary) {
                viewModel.approveSelected()
            }
            .accessibilityLabel("Approve all selected reviews")
            .accessibilityAddTraits(.isButton)

            AnvilButton("Clear", style: .ghost) {
                viewModel.selectedReviewIDs.removeAll()
            }
            .accessibilityLabel("Clear selection")
            .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Batch actions for \(viewModel.selectedReviewIDs.count) selected reviews")
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
            .accessibilityLabel("Review status: \(String(describing: status))")
    }

}
