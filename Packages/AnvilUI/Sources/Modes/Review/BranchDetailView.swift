import SwiftUI
import AnvilDomain

struct BranchDetailView: View {
    let branch: Branch
    @ObservedObject var viewModel: ReviewViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AnvilSpacing.md) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 18, weight: .light))
                    .foregroundStyle(branch.isCurrent ? AnvilColor.accentGreen : AnvilColor.accentBlue)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxxs) {
                    Text(branch.name)
                        .font(AnvilFont.heading)
                        .foregroundStyle(AnvilColor.textPrimary)

                    if let upstream = branch.upstream {
                        Text("Tracking \(upstream)")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }

                Spacer()

                AnvilButton("Start Review", icon: "play.fill", style: .primary) {
                    guard let firstFile = viewModel.branchDiffFiles.first else { return }
                    viewModel.selectFile(firstFile.id)
                }
                .disabled(viewModel.branchDiffFiles.isEmpty)

                if branch.isCurrent {
                    AnvilBadge(text: "Current", color: AnvilColor.accentGreen)
                }
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.md)
            .background(.bar)

            Divider()

            // Stats
            HStack(spacing: AnvilSpacing.xl) {
                statCard(
                    icon: "arrow.up",
                    label: "Ahead",
                    value: "\(branch.aheadCount)",
                    color: branch.aheadCount > 0 ? AnvilColor.accentGreen : AnvilColor.textTertiary
                )

                statCard(
                    icon: "arrow.down",
                    label: "Behind",
                    value: "\(branch.behindCount)",
                    color: branch.behindCount > 0 ? AnvilColor.accentRed : AnvilColor.textTertiary
                )

                statCard(
                    icon: "doc.on.doc",
                    label: "Changed Files",
                    value: "\(viewModel.branchDiffFiles.count)",
                    color: viewModel.branchDiffFiles.isEmpty ? AnvilColor.textTertiary : AnvilColor.accentAmber
                )
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.lg)

            Divider()

            // Last commit
            if let message = branch.lastCommitMessage {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    Text("Last Commit")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)

                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text(message)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .lineLimit(3)
                    }

                    if let date = branch.lastCommitDate {
                        Text(date, style: .relative)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.vertical, AnvilSpacing.md)

                Divider()
            }

            // Changed files list
            if viewModel.isLoadingBranchDiff {
                Spacer()
                ProgressView("Loading diff...")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                Spacer()
            } else if !viewModel.branchDiffFiles.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    AnvilSidebarSectionHeader(
                        title: "Changed Files",
                        icon: "doc",
                        count: viewModel.branchDiffFiles.count
                    )
                    .padding(.horizontal, AnvilSpacing.lg)
                    .padding(.vertical, AnvilSpacing.sm)

                    List {
                        ForEach(viewModel.branchDiffFiles) { file in
                            branchFileRow(file)
                                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 8))
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.sidebar)
                }
            } else {
                Spacer()
                Text("No changes between this branch and base")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                Spacer()
            }
        }
    }

    // MARK: - Components

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: AnvilSpacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundStyle(color)

            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(minWidth: 80)
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func branchFileRow(_ file: FileDiff) -> some View {
        AnvilSidebarRowButton(
            title: file.filePath.components(separatedBy: "/").last ?? file.filePath,
            icon: fileIcon(for: file.status),
            subtitle: file.filePath.components(separatedBy: "/").dropLast().joined(separator: "/"),
            isActive: viewModel.selectedFileID == file.id
        ) {
            viewModel.selectFile(file.id)
        }
        .accessibilityLabel("\(file.filePath.components(separatedBy: "/").last ?? file.filePath), \(file.status)")
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
