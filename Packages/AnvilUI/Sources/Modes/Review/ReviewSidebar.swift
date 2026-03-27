import SwiftUI
import AnvilDomain

struct ReviewSidebar: View {
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            // File list for selected review
            if let review = viewModel.selectedReview {
                reviewFileList(review)
            } else {
                groupedReviewList
            }
        }
    }

    // MARK: - Grouped Review List (no review selected)

    private var groupedReviewList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                if !viewModel.pendingReviews.isEmpty {
                    reviewSection("Pending", icon: "circle", reviews: viewModel.pendingReviews)
                }
                if !viewModel.completedReviews.isEmpty {
                    reviewSection("Completed", icon: "checkmark.circle", reviews: viewModel.completedReviews)
                }
            }
        }
    }

    private func reviewSection(_ title: String, icon: String, reviews: [Review]) -> some View {
        Section {
            ForEach(reviews) { review in
                AnvilListItem(
                    icon: reviewIcon(for: review),
                    title: review.title,
                    subtitle: review.author,
                    tag: review.sourceId,
                    tagColor: review.sourceType == .pullRequest
                        ? AnvilColor.accentBlue
                        : AnvilColor.accentPurple,
                    isSelected: viewModel.selectedReviewID == review.id,
                    isCompact: false
                )
                .onTapGesture { viewModel.selectReview(review.id) }
            }
        } header: {
            sectionHeader(title, icon: icon, count: reviews.count)
        }
    }

    // MARK: - File List (review selected)

    private func reviewFileList(_ review: Review) -> some View {
        VStack(spacing: 0) {
            // Back button
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    viewModel.selectedReviewID = nil
                    viewModel.selectedFileID = nil
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Back")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                statusBadge(review.status)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            // Review title
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                Text(review.title)
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(2)

                Text("\(review.author) \u{2022} \(review.diff.count) files")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            // Files
            ScrollView {
                LazyVStack(spacing: 0) {
                    Section {
                        ForEach(review.diff) { file in
                            fileRow(file)
                        }
                    } header: {
                        sectionHeader("Files", icon: "doc", count: review.diff.count)
                    }
                }
            }
        }
    }

    private func fileRow(_ file: FileDiff) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: fileIcon(for: file.status))
                .font(.system(size: 12))
                .foregroundStyle(fileColor(for: file.status))
                .frame(width: 16)

            Text(file.filePath.components(separatedBy: "/").last ?? file.filePath)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            // Hunk decision summary
            let approved = file.hunks.filter { viewModel.decisionFor($0.id) == .approved }.count
            let total = file.hunks.count
            if approved > 0 {
                Text("\(approved)/\(total)")
                    .font(AnvilFont.label)
                    .foregroundStyle(
                        approved == total ? AnvilColor.accentGreen : AnvilColor.textTertiary
                    )
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .frame(height: AnvilSpacing.listItemHeight)
        .background(
            viewModel.selectedFileID == file.id
                ? AnvilColor.selectionBackground
                : Color.clear
        )
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectFile(file.id) }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)

            Text(title.uppercased())
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .tracking(0.3)

            Spacer()

            Text("\(count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    private func statusBadge(_ status: ReviewStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .pending: ("Pending", AnvilColor.accentAmber)
        case .approved: ("Approved", AnvilColor.accentGreen)
        case .changesRequested: ("Changes", AnvilColor.accentRed)
        case .dismissed: ("Dismissed", AnvilColor.textTertiary)
        }
        return AnvilBadge(text: text, color: color)
    }

    private func reviewIcon(for review: Review) -> String {
        switch review.status {
        case .pending: "circle"
        case .approved: "checkmark.circle.fill"
        case .changesRequested: "exclamationmark.circle.fill"
        case .dismissed: "minus.circle"
        }
    }

    private func fileIcon(for status: DiffFileStatus) -> String {
        switch status {
        case .added: "plus.circle.fill"
        case .modified: "pencil.circle.fill"
        case .deleted: "minus.circle.fill"
        case .renamed: "arrow.right.circle.fill"
        case .copied: "doc.on.doc.fill"
        }
    }

    private func fileColor(for status: DiffFileStatus) -> Color {
        switch status {
        case .added: AnvilColor.accentGreen
        case .modified: AnvilColor.accentAmber
        case .deleted: AnvilColor.accentRed
        case .renamed: AnvilColor.accentBlue
        case .copied: AnvilColor.accentPurple
        }
    }
}
