import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - Remote Section

struct SCPRemoteSection: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        Section {
            if viewModel.isRemoteSectionExpanded {
                // Error banner
                if let error = viewModel.remoteError {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                        Text(error)
                            .font(AnvilFont.label)
                            .lineLimit(2)
                        Spacer()
                        Button {
                            viewModel.remoteError = nil
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

                // Add remote form
                VStack(spacing: AnvilSpacing.xs) {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Name", text: $viewModel.newRemoteName)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)
                            .frame(width: 100)

                        TextField("URL", text: $viewModel.newRemoteURL)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.addRemote(using: adapter)
                        } label: {
                            Text("Add")
                                .font(AnvilFont.label)
                                .foregroundStyle(
                                    viewModel.newRemoteName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    viewModel.newRemoteURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? AnvilColor.textTertiary
                                        : AnvilColor.accentBlue
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)

                // Remote list
                if viewModel.remotes.isEmpty {
                    HStack {
                        Text("No remotes configured")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.remotes) { remote in
                        SCPRemoteRow(viewModel: viewModel, remote: remote)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isRemoteSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isRemoteSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("Remotes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.remotes.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.background)
        }
    }
}

// MARK: - Remote Row

struct SCPRemoteRow: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    let remote: GitRemote

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "network")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentBlue)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(remote.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                Text(remote.fetchURL)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            // Remove button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.removeRemote(remote.name, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Remove remote")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }
}
