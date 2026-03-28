import SwiftUI

struct DocEditor: View {
    @ObservedObject var viewModel: DocsViewModel

    var body: some View {
        if viewModel.selectedDoc != nil {
            HSplitView {
                // Left: Raw markdown editor
                editorPane

                // Right: Preview (simplified rendered view)
                previewPane
            }
        } else {
            emptyState
        }
    }

    // MARK: - Editor Pane

    private var editorPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("EDIT")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)

                if viewModel.isModified {
                    Circle()
                        .fill(AnvilColor.accentAmber)
                        .frame(width: 6, height: 6)
                        .help("Unsaved changes")
                }

                Spacer()

                if viewModel.isModified {
                    Button {
                        viewModel.saveCurrentDocument()
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 10))
                            Text("Save")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentBlue)
                    }
                    .buttonStyle(.plain)
                    .help("Save (Cmd+S)")
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            TextEditor(text: $viewModel.editorContent)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(AnvilSpacing.sm)
                .onChange(of: viewModel.editorContent) { _, _ in
                    viewModel.markModified()
                }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PREVIEW")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .tracking(0.3)
                Spacer()

                if let doc = viewModel.selectedDoc {
                    Text(doc.name)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    ForEach(Array(viewModel.editorContent.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                        renderedLine(line)
                    }
                }
                .padding(AnvilSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Simple Markdown Rendering

    private func renderedLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        return Group {
            if trimmed.hasPrefix("# ") {
                Text(trimmed.dropFirst(2))
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
            } else if trimmed.hasPrefix("## ") {
                Text(trimmed.dropFirst(3))
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)
            } else if trimmed.hasPrefix("### ") {
                Text(trimmed.dropFirst(4))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AnvilColor.textPrimary)
            } else if trimmed.hasPrefix("- ") {
                HStack(alignment: .top, spacing: AnvilSpacing.xs) {
                    Text("\u{2022}")
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text(trimmed.dropFirst(2))
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
            } else if trimmed.hasPrefix("```") {
                // Code fence markers are visual-only in preview
                EmptyView()
            } else if trimmed.isEmpty {
                Spacer().frame(height: AnvilSpacing.xs)
            } else {
                Text(trimmed)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("Select a document to edit")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnvilColor.backgroundPrimary)
    }
}
