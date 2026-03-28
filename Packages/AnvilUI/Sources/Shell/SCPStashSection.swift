import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - Stash Section

struct SCPStashSection: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        Section {
            if viewModel.isStashSectionExpanded {
                // Stash current changes row
                if viewModel.totalChangeCount > 0 {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Stash message (optional)", text: $viewModel.stashMessage)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.stashChanges(using: adapter)
                        } label: {
                            Text("Stash")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentBlue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                }

                // Stash list
                if viewModel.stashes.isEmpty {
                    HStack {
                        Text("No stashes")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.stashes) { stash in
                        SCPStashRow(viewModel: viewModel, stash: stash)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isStashSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isStashSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "tray.and.arrow.down")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("Stashes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.stashes.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)

                if !viewModel.stashes.isEmpty {
                    Button {
                        guard let adapter = container.getOrCreateGitAdapter() else { return }
                        viewModel.popStash(using: adapter)
                    } label: {
                        Text("Pop")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .help("Pop most recent stash")
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.background)
        }
    }
}

// MARK: - Stash Row

struct SCPStashRow: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    let stash: Stash

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(stash.message.isEmpty ? "stash@{\(stash.index)}" : stash.message)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(stash.date, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            // Apply button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.applyStash(index: stash.index, using: adapter)
            } label: {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Apply this stash")

            // Drop button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.dropStash(index: stash.index, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Drop this stash")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }
}
