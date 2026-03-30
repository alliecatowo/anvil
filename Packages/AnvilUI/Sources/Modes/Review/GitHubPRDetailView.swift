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
                    Divider()

                    VStack(alignment: .leading, spacing: AnvilSpacing.xxl) {
                        headerSection(pr)
                        ciSection
                        mergeSection(pr)
                        commentsSection
                    }
                    .padding(AnvilSpacing.xxl)
                }
            }
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
                        .accessibilityHidden(true)
                    Text("Back")
                        .font(AnvilFont.label)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to pull request list")
            .accessibilityAddTraits(.isButton)

            Spacer()

            prStatusBadge(pr.status)

            if pr.isDraft {
                AnvilBadge(text: "Draft", color: AnvilColor.textTertiary)
                    .accessibilityLabel("Draft pull request")
            }

            Text("#\(pr.number)")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .accessibilityLabel("Pull request number \(pr.number)")
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
                        .accessibilityHidden(true)
                    Text(pr.sourceBranch)
                        .font(AnvilFont.code)
                }
                .foregroundStyle(AnvilColor.accentBlue)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .accessibilityHidden(true)

                Text(pr.targetBranch)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Branch \(pr.sourceBranch) into \(pr.targetBranch)")

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
                        .accessibilityHidden(true)
                    Text(pr.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Author: \(pr.author)")

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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(pr.additions) additions, \(pr.deletions) deletions, \(pr.changedFiles) files changed")

                // Reviewers
                if !pr.reviewers.isEmpty {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "person.2")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .accessibilityHidden(true)
                        Text(pr.reviewers.joined(separator: ", "))
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Reviewers: \(pr.reviewers.joined(separator: ", "))")
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
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Labels: \(pr.labels.joined(separator: ", "))")
            }

            // Body
            if !pr.body.isEmpty {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("Description")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

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
                Text("CI Checks")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Spacer()

                let summary = viewModel.ciSummary
                if summary.passed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("\(summary.passed)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentGreen)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(summary.passed) checks passed")
                }
                if summary.failed > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("\(summary.failed)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(summary.failed) checks failed")
                }
                if summary.pending > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("\(summary.pending)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(summary.pending) checks pending")
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
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Check \(check.name), \(check.conclusion?.rawValue.capitalized ?? check.status.rawValue.capitalized)")
    }

    // MARK: - Merge Section

    private func mergeSection(_ pr: PullRequest) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Merge")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            if pr.status == .merged {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentPurple)
                        .accessibilityHidden(true)
                    Text("This pull request has been merged.")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .padding(AnvilSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This pull request has been merged")
            } else if pr.status == .closed {
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AnvilColor.accentRed)
                        .accessibilityHidden(true)
                    Text("This pull request has been closed.")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .padding(AnvilSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("This pull request has been closed")
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
                                    .accessibilityHidden(true)
                                Text("\(summary.failed) check(s) failing")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentRed)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(summary.failed) checks failing")
                        } else if summary.pending > 0 {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.accentAmber)
                                    .accessibilityHidden(true)
                                Text("\(summary.pending) check(s) pending")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentAmber)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(summary.pending) checks pending")
                        } else if summary.passed > 0 {
                            HStack(spacing: AnvilSpacing.xxs) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AnvilColor.accentGreen)
                                    .accessibilityHidden(true)
                                Text("All checks passed")
                                    .font(AnvilFont.label)
                                    .foregroundStyle(AnvilColor.accentGreen)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("All checks passed")
                        }

                        Spacer()

                        if pr.isDraft {
                            AnvilBadge(text: "Draft — cannot merge", color: AnvilColor.textTertiary)
                                .accessibilityLabel("Draft, cannot merge")
                        }
                    }

                    // Update branch
                    HStack(spacing: AnvilSpacing.sm) {
                        if pr.behindCount > 0 {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(AnvilColor.accentAmber)
                                .accessibilityHidden(true)
                            Text("Branch is \(pr.behindCount) commit\(pr.behindCount == 1 ? "" : "s") behind \(pr.targetBranch)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentAmber)
                        } else {
                            Image(systemName: "arrow.triangle.merge")
                                .font(.system(size: 12))
                                .foregroundStyle(AnvilColor.textTertiary)
                                .accessibilityHidden(true)
                            Text("Update with latest from \(pr.targetBranch)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textSecondary)
                        }

                        Spacer()

                        if viewModel.isUpdatingBranch {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Updating branch")
                        }

                        AnvilButton("Update Branch", icon: "arrow.triangle.merge", style: .secondary) {
                            guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                            viewModel.updateBranch(using: adapter)
                        }
                        .disabled(viewModel.isUpdatingBranch)
                        .accessibilityLabel("Update branch with latest from \(pr.targetBranch)")
                        .accessibilityAddTraits(.isButton)
                    }

                    // Update branch error
                    if let error = viewModel.updateBranchError {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text(error)
                                .font(AnvilFont.label)
                                .lineLimit(2)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Error: \(error)")
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
                            .accessibilityLabel("Merge strategy")

                            Spacer()

                            if viewModel.isMerging {
                                ProgressView()
                                    .controlSize(.small)
                                    .accessibilityLabel("Merging pull request")
                            }

                            AnvilButton("Merge Pull Request", icon: "arrow.triangle.merge", style: .cta) {
                                guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                                viewModel.mergePR(using: adapter)
                            }
                            .opacity(viewModel.canMerge ? 1.0 : 0.5)
                            .accessibilityLabel("Merge pull request")
                            .accessibilityAddTraits(.isButton)
                        }
                    }

                    // Error
                    if let error = viewModel.mergeError {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text(error)
                                .font(AnvilFont.label)
                                .lineLimit(2)
                        }
                        .foregroundStyle(AnvilColor.accentRed)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Merge error: \(error)")
                    }
                }
                .padding(AnvilSpacing.md)
            }
        }
    }

    // MARK: - Comments (Threaded)

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Header with thread counts
            HStack {
                Text("Comments (\(viewModel.prComments.count))")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                Spacer()

                if viewModel.resolvedThreadCount > 0 {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("\(viewModel.resolvedThreadCount) resolved")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentGreen)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(viewModel.resolvedThreadCount) resolved threads")
                }

                if viewModel.unresolvedThreadCount > 0 {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text("\(viewModel.unresolvedThreadCount) open")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(viewModel.unresolvedThreadCount) open threads")
                }
            }

            if viewModel.commentThreads.isEmpty {
                Text("No comments yet")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .italic()
            } else {
                // Unresolved threads first, then resolved
                let unresolved = viewModel.commentThreads.filter { !$0.isResolved }
                let resolved = viewModel.commentThreads.filter { $0.isResolved }

                ForEach(unresolved) { thread in
                    threadView(thread)
                }

                if !resolved.isEmpty {
                    DisclosureGroup {
                        ForEach(resolved) { thread in
                            threadView(thread)
                        }
                    } label: {
                        Text("\(resolved.count) resolved thread\(resolved.count == 1 ? "" : "s")")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .tint(AnvilColor.textTertiary)
                    .accessibilityLabel("\(resolved.count) resolved threads")
                }
            }

            // Reply error
            if let error = viewModel.replyError {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 10))
                        .accessibilityHidden(true)
                    Text(error)
                        .font(AnvilFont.label)
                        .lineLimit(2)
                }
                .foregroundStyle(AnvilColor.accentRed)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reply error: \(error)")
            }
        }
    }

    private func threadView(_ thread: PRCommentThread) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Root comment
            commentRow(thread.rootComment)

            // Thread controls
            HStack(spacing: AnvilSpacing.md) {
                // Expand/collapse replies
                if thread.replyCount > 0 {
                    Button {
                        viewModel.toggleThread(thread.id)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: viewModel.expandedThreads.contains(thread.id) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .accessibilityHidden(true)
                            Text("\(thread.replyCount) repl\(thread.replyCount == 1 ? "y" : "ies")")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(thread.replyCount) replies, \(viewModel.expandedThreads.contains(thread.id) ? "collapse" : "expand")")
                    .accessibilityAddTraits(.isButton)
                }

                Spacer()

                // Resolve / unresolve
                if thread.isResolved {
                    Button {
                        viewModel.unresolveThread(thread.id)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 9))
                                .accessibilityHidden(true)
                            Text("Unresolve")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Unresolve thread")
                    .accessibilityAddTraits(.isButton)
                } else {
                    Button {
                        guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                        viewModel.resolveThread(thread.id, using: adapter)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 10))
                                .accessibilityHidden(true)
                            Text("Resolve")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Resolve thread")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            // Expanded replies
            if viewModel.expandedThreads.contains(thread.id) && thread.replyCount > 0 {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(thread.replies) { reply in
                        replyRow(reply)
                    }
                }
                .padding(.leading, AnvilSpacing.xl)
            }

            // Reply input (always visible for unresolved threads)
            if !thread.isResolved {
                replyInput(threadId: thread.id)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.bottom, AnvilSpacing.sm)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .opacity(thread.isResolved ? 0.7 : 1.0)
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
                    .accessibilityHidden(true)

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
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(comment.author)\(comment.filePath.map { " on \($0)" } ?? "")\(comment.lineNumber.map { " line \($0)" } ?? "")")

            Text(comment.body)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .textSelection(.enabled)
        }
        .padding(AnvilSpacing.md)
    }

    private func replyRow(_ comment: PRComment) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
            HStack(spacing: AnvilSpacing.xs) {
                Circle()
                    .fill(AnvilColor.backgroundElevated)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text(String(comment.author.prefix(1)).uppercased())
                            .font(.system(size: 7, weight: .medium))
                            .foregroundStyle(AnvilColor.textSecondary)
                    )
                    .accessibilityHidden(true)

                Text(comment.author)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Text(comment.createdAt, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reply by \(comment.author)")

            Text(comment.body)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .textSelection(.enabled)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private func replyInput(threadId: String) -> some View {
        HStack(spacing: AnvilSpacing.xs) {
            TextField("Reply...", text: Binding(
                get: { viewModel.replyText[threadId] ?? "" },
                set: { viewModel.replyText[threadId] = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .font(AnvilFont.body)
            .accessibilityLabel("Reply to thread")

            if viewModel.isReplying {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Sending reply")
            } else {
                Button {
                    guard let adapter = container.getOrCreateGitHubAdapter() else { return }
                    viewModel.replyToThread(threadId, using: adapter)
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(
                            (viewModel.replyText[threadId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? AnvilColor.textTertiary
                            : AnvilColor.accentBlue
                        )
                }
                .buttonStyle(.plain)
                .disabled((viewModel.replyText[threadId] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send reply")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    // MARK: - Helpers

    private func prStatusBadge(_ status: PRStatus) -> some View {
        let (text, color): (String, Color) = switch status {
        case .open:   ("Open", AnvilColor.accentGreen)
        case .merged: ("Merged", AnvilColor.accentPurple)
        case .closed: ("Closed", AnvilColor.accentRed)
        }
        return AnvilBadge(text: text, color: color)
            .accessibilityLabel("Status: \(text)")
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
