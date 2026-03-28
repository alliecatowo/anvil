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
                Text("Edit")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)

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
            .background(.bar)

            Divider()

            TextEditor(text: $viewModel.editorContent)
                .font(AnvilFont.code)
                .foregroundStyle(.primary)
                .scrollContentBackground(.hidden)
                .padding(AnvilSpacing.sm)
                .onChange(of: viewModel.editorContent) { _, _ in
                    viewModel.markModified()
                }
        }
        .background(.background)
    }

    // MARK: - Preview Pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Preview")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
                Spacer()

                if let doc = viewModel.selectedDoc {
                    Text(doc.name)
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.bar)

            Divider()

            ScrollView {
                MarkdownPreview(source: viewModel.editorContent)
                    .padding(AnvilSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.background)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(.tertiary.opacity(0.5))

            Text("Select a document to edit")
                .font(AnvilFont.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}

// MARK: - Markdown Preview

private struct MarkdownPreview: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(renderedBlocks, id: \.id) { block in
                blockView(block)
            }
        }
    }

    // MARK: - Block Model

    private struct MarkdownBlock: Identifiable {
        let id: Int
        let kind: Kind

        enum Kind {
            case h1(String)
            case h2(String)
            case h3(String)
            case h4(String)
            case bullet(String)
            case code([String])
            case body(String)
            case spacer
        }
    }

    // MARK: - Parsing

    private var renderedBlocks: [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var codeLines: [String] = []
        var inCode = false
        var index = 0

        for line in source.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if inCode {
                    // Close code block
                    blocks.append(MarkdownBlock(id: index, kind: .code(codeLines)))
                    index += 1
                    codeLines = []
                    inCode = false
                } else {
                    inCode = true
                }
                continue
            }

            if inCode {
                codeLines.append(line)
                continue
            }

            if trimmed.hasPrefix("#### ") {
                blocks.append(MarkdownBlock(id: index, kind: .h4(String(trimmed.dropFirst(5)))))
            } else if trimmed.hasPrefix("### ") {
                blocks.append(MarkdownBlock(id: index, kind: .h3(String(trimmed.dropFirst(4)))))
            } else if trimmed.hasPrefix("## ") {
                blocks.append(MarkdownBlock(id: index, kind: .h2(String(trimmed.dropFirst(3)))))
            } else if trimmed.hasPrefix("# ") {
                blocks.append(MarkdownBlock(id: index, kind: .h1(String(trimmed.dropFirst(2)))))
            } else if trimmed.hasPrefix("- ") {
                blocks.append(MarkdownBlock(id: index, kind: .bullet(String(trimmed.dropFirst(2)))))
            } else if trimmed.isEmpty {
                blocks.append(MarkdownBlock(id: index, kind: .spacer))
            } else {
                blocks.append(MarkdownBlock(id: index, kind: .body(trimmed)))
            }
            index += 1
        }

        // Unclosed code fence: emit remaining lines as code
        if inCode && !codeLines.isEmpty {
            blocks.append(MarkdownBlock(id: index, kind: .code(codeLines)))
        }

        return blocks
    }

    // MARK: - Block View

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .h1(let text):
            Text(text)
                .font(.title)
                .foregroundStyle(.primary)
                .padding(.top, AnvilSpacing.sm)

        case .h2(let text):
            Text(text)
                .font(.title2)
                .foregroundStyle(.primary)
                .padding(.top, AnvilSpacing.xs)

        case .h3(let text):
            Text(text)
                .font(.title3)
                .foregroundStyle(.primary)

        case .h4(let text):
            Text(text)
                .font(.headline)
                .foregroundStyle(.primary)

        case .bullet(let text):
            HStack(alignment: .top, spacing: AnvilSpacing.xs) {
                Text("\u{2022}")
                    .font(AnvilFont.body)
                    .foregroundStyle(.tertiary)
                inlineText(text)
                    .font(AnvilFont.body)
                    .foregroundStyle(.secondary)
            }

        case .code(let lines):
            Text(lines.joined(separator: "\n"))
                .font(AnvilFont.code)
                .foregroundStyle(.primary)
                .padding(AnvilSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))

        case .body(let text):
            inlineText(text)
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)

        case .spacer:
            Spacer().frame(height: AnvilSpacing.xs)
        }
    }

    // MARK: - Inline Markdown

    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(markdown: text) {
            return Text(attributed)
        }
        return Text(text)
    }
}
