import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - History Section

struct SCPHistorySection: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        Section {
            if viewModel.isHistorySectionExpanded {
                // Action error
                if let error = viewModel.actionError {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text(error)
                            .font(AnvilFont.label)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.actionError = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(AnvilColor.accentRed)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.accentRed.opacity(0.1))
                }

                if viewModel.recentCommits.isEmpty {
                    HStack {
                        Text("No commits")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.recentCommits) { commit in
                        SCPCommitRow(viewModel: viewModel, commit: commit)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isHistorySectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isHistorySectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("History")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.recentCommits.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.background)
        }
    }
}

// MARK: - Commit Row

struct SCPCommitRow: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    let commit: Commit

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Commit hash
            Text(commit.shortHash)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(AnvilColor.accentBlue.opacity(0.8))
                .frame(width: 50, alignment: .leading)

            // Message
            VStack(alignment: .leading, spacing: 0) {
                Text(commit.message)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(commit.author)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text(commit.date, style: .relative)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }

            Spacer()

            // Cherry-pick button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.cherryPick(commit.id, using: adapter)
            } label: {
                Image(systemName: "cherry")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Cherry-pick this commit")

            // Revert button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.revertCommit(commit.id, using: adapter)
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentAmber)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Revert this commit")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }
}
