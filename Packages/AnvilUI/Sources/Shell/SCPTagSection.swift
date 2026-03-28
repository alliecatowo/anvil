import SwiftUI
import AnvilDomain
import AnvilApplication
import AnvilGit

// MARK: - Tag Section

struct SCPTagSection: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    var body: some View {
        Section {
            if viewModel.isTagSectionExpanded {
                // Create tag row
                VStack(spacing: AnvilSpacing.xs) {
                    HStack(spacing: AnvilSpacing.sm) {
                        TextField("Tag name", text: $viewModel.newTagName)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)

                        Button {
                            guard let adapter = container.getOrCreateGitAdapter() else { return }
                            viewModel.createTag(using: adapter)
                        } label: {
                            Text("Create")
                                .font(AnvilFont.label)
                                .foregroundStyle(
                                    viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                        ? AnvilColor.textTertiary
                                        : AnvilColor.accentBlue
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    TextField("Annotation (optional)", text: $viewModel.newTagMessage)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.label)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)

                // Tag list
                if viewModel.tags.isEmpty {
                    HStack {
                        Text("No tags")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .italic()
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                } else {
                    ForEach(viewModel.tags) { tag in
                        SCPTagRow(viewModel: viewModel, tag: tag)
                    }
                }
            }
        } header: {
            HStack {
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        viewModel.isTagSectionExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.isTagSectionExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 10)

                        Image(systemName: "tag")
                            .font(.system(size: 10))
                            .foregroundStyle(AnvilColor.textTertiary)

                        Text("Tags")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.tags.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.background)
        }
    }
}

// MARK: - Tag Row

struct SCPTagRow: View {
    @ObservedObject var viewModel: SourceControlViewModel
    @EnvironmentObject var container: DependencyContainer

    let tag: Tag

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: tag.annotation != nil ? "tag.fill" : "tag")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentAmber)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(tag.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1)

                HStack(spacing: AnvilSpacing.xs) {
                    Text(tag.targetCommit.prefix(7))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentBlue.opacity(0.7))

                    if let annotation = tag.annotation, !annotation.isEmpty {
                        Text(annotation)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let date = tag.date {
                Text(date, style: .relative)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Delete button
            Button {
                guard let adapter = container.getOrCreateGitAdapter() else { return }
                viewModel.deleteTag(tag.name, using: adapter)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AnvilColor.accentRed)
                    .frame(width: 22, height: 22)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Delete tag")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .contentShape(Rectangle())
    }
}
