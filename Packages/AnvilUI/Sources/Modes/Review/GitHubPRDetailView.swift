import SwiftUI
import AnvilDomain
import AnvilGitHub

struct GitHubPRDetailView: View {
    @ObservedObject var viewModel: GitHubPRViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        if let pr = viewModel.selectedPR {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Back bar
                    backBar(pr)
                    Divider().overlay(AnvilColor.borderSubtle)

                    VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                        headerSection(pr)
                        ciSection
                        mergeSection(pr)
                        commentsSection
                    }
                    .padding(AnvilSpacing.xxl)
                }
            }
            .background(AnvilColor.backgroundPrimary)
        }
    }

    // MARK: - Back Bar

    private func backBar(_ pr: PullRequest) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Button {
                viewModel.clearSelection()
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

            prStatusBadge(pr.status)

            if pr.isDraft {
                AnvilBadge(text: "Draft", color: AnvilColor.textTertiary)
            }

            Text("#\(pr.number)")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Header

    private func headerSection(_ pr: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.md) {
            Text(pr.title)
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            // Branch info
            HStack(spacing: AnvilSpacing.sm) {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                    Text(pr.sourceBranch)
                        .font(AnvilFont.code)
                }
                .foregroundStyle(AnvilColor.accentBlue)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)

                Text(pr.targetBranch)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            // Metadata row
            HStack(spacing: AnvilSpacing.lg) {
                // Author
                HStack(spacing: AnvilSpacing.xxs) {
                    Circle()
                        .fill(AnvilColor.backgroundElevated)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(pr.author.prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AnvilColor.textSecondary)
                        )
                    Text(pr.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                }

                // Changes
                HStack(spacing: AnvilSpacing.xs) {
                    Text("+\(pr.additions)")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentGreen)
                    Text("-\(pr.deletions)")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentRed)
                    Text("\(pr.changedFiles) files")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                // Reviewers
                if !pr.reviewers.isEmpty {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(pr.reviewers.joined(separator: ", "))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                }

                Spacer()
            }

            // Labels
            if !pr.labels.isEmpty {
                FlowLayout(spacing: AnvilSpacing.xs) {
                    ForEach(pr.labels, id: \.self) { label in
                        AnvilBadge(text: label, color: AnvilColor.accentBlue)
                    }
                }
            }

            // Body
            if !pr.body.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("DESCRIPTION")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .tracking(0.3)

                    Text(pr.body)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
            }
        }
    }

    // MARK: - CI Checks

    private var ciSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            HStack {
                Text("CI CHECKS")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                Spacer()

                let summary = viewModel.ciSummary
                if summary.passed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("\(summary.passed)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentGreen)
                }
                if summary.failed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                        Text("\(summary.failed)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                }
                if summary.pending > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(summary.pending)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                }
            }

            if viewModel.ciChecks.isEmpty {
                Text("No CI checks")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
            } else {
                ForEach(viewModel.ciChecks) { check in
                    ciCheckRow(check)
                }
            }
        }
    }

    private func ciCheckRow(_ check: CICheck) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: ciIcon(check))
                .font(.system(size: 12))
                .foregroundStyle(ciColor(check))
                .frame(width: 16)

            Text(check.name)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer()

            if let conclusion = check.conclusion {
                Text(conclusion.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(ciColor(check))
            } else {
                Text(check.status.rawValue.capitalized)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentAmber)
            }
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Merge Section

    private func mergeSection(_ pr: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("MERGE")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)

            if pr.status == .merged {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentPurple)
                    Text("This pull request has been merged.")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .padding(AnvilSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnvilColor.accentPurple.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if pr.status == .closed {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentRed)
                    Text("This pull request has been closed.")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .padding(AnvilSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AnvilColor.accentRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                // Open PR — show merge controls
                VStack(spacing: AnvilSpacing.md) {
                    // CI summary bar
                    let summary = viewModel.ciSummary
                    HStack(spacing: AnvilSpacing.md) {
                        if summary.failed > 0 {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.accentRed)
                                Text("\(summary.failed) check(s) failing")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentRed)
                            }
                        } else if summary.pending > 0 {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.accentAmber)
                                Text("\(summary.pending) check(s) pending")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentAmber)
                            }
                        } else if summary.passed > 0 {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.accentGreen)
                                Text("All checks passed")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentGreen)
                            }
                        }

                        Spacer()

                        if pr.isDraft {
                            AnvilBadge(text: "Draft — cannot merge", color: AnvilColor.textTertiary)
                        }
                    }

                    // Update branch
                    HStack(spacing: AnvilSpacing.sm) {
                        if pr.behindCount > 0 {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(AnvilColor.accentAmber)
                            Text("Branch is \(pr.behindCount) commit\(pr.behindCount == 1 ? "" : "s") behind \(pr.targetBranch)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentAmber)
                        } else {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 12))
                                .foregroundStyle(AnvilColor.textTertiary)
                            Text("Update with latest from \(pr.targetBranch)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textSecondary)
                        }

                        Spacer()

                        if viewModel.isUpdatingBranch {
                            ProgressView()
                                .controlSize(.small)
                        }

                        AnvilButton("Update Branch", icon: "arrow.triangle.merge", style: .secondary) {
                            guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                            viewModel.updateBranch(using: adapter)
                        }
                        .disabled(viewModel.isUpdatingBranch)
                    }

                    // Update branch error
                    if let error = viewModel.updateBranchError {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 10))
                            Text(error)
                                .font(AnvilFont.label)
                                .lineLimit(2)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                    }

                    // Merge strategy + button
                    if !pr.isDraft {
                        HStack(spacing: AnvilSpacing.md) {
                            Picker("Strategy", selection: $viewModel.selectedMergeStrategy) {
                                Text("Squash & Merge").tag(MergeStrategy.squash)
                                Text("Merge Commit").tag(MergeStrategy.merge)
                                Text("Rebase & Merge").tag(MergeStrategy.rebase)
                            }
                            .pickerStyle(.segmented)
                            .frame(maxWidth: 360)

                            Spacer()

                            if viewModel.isMerging {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            AnvilButton("Merge Pull Request", icon: "arrow.triangle.merge", style: .primary) {
                                guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                                viewModel.mergePR(using: adapter)
                            }
                            .opacity(viewModel.canMerge ? 1.0 : 0.5)
                        }
                    }

                    // Error
                    if let error = viewModel.mergeError {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 10))
                            Text(error)
                                .font(AnvilFont.label)
                                .lineLimit(2)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                    }
                }
                .padding(AnvilSpacing.md)
                .background(AnvilColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("COMMENTS (\(viewModel.prComments.count))")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .tracking(0.3)

            if viewModel.prComments.isEmpty {
                Text("No comments yet")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
            } else {
                ForEach(viewModel.prComments) { comment in
                    commentRow(comment)
                }
            }
        }
    }

    private func commentRow(_ comment: PRComment) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            HStack {
                Circle()
                    .fill(AnvilColor.backgroundElevated)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Text(String(comment.author.prefix(1)).uppercased())
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AnvilColor.textSecondary)
                    )

                Text(comment.author)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textPrimary)

                if let path = comment.filePath {
                    Text(path)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentBlue)
                        .lineLimit(1)

                    if let line = comment.lineNumber {
                        Text("L\(line)")
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }

                Spacer()

                Text(comment.createdAt, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Text(comment.body)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .textSelection(.enabled)
        }
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Helpers

    private func prStatusBadge(_ status: PRStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .open:   ("Open", AnvilColor.accentGreen)
        case .merged: ("Merged", AnvilColor.accentPurple)
        case .closed: ("Closed", AnvilColor.accentRed)
        }
        return AnvilBadge(text: text, color: color)
    }

    private func ciIcon(_ check: CICheck) -> String {
        switch check.conclusion {
        case .success:   "checkmark.circle.fill"
        case .failure:   "xmark.circle.fill"
        case .cancelled: "minus.circle.fill"
        case .skipped:   "forward.circle.fill"
        case .timedOut:  "clock.badge.exclamationmark"
        case nil:
            switch check.status {
            case .queued:     "clock"
            case .inProgress: "arrow.clockwise.circle"
            case .completed:  "checkmark.circle"
            }
        }
    }

    private func ciColor(_ check: CICheck) -> Color {
        switch check.conclusion {
        case .success:            AnvilColor.accentGreen
        case .failure:            AnvilColor.accentRed
        case .cancelled, .skipped: AnvilColor.textTertiary
        case .timedOut:           AnvilColor.accentAmber
        case nil:                 AnvilColor.accentAmber
        }
    }
}
