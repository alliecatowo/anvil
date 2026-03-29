import SwiftUI
import AnvilEditor

/// Floating LSP completion popup shown below the cursor in the editor.
struct CompletionPopup: View {
    @ObservedObject var viewModel: EditorViewModel

    /// Maximum visible items before scrolling.
    private let maxVisible = 8
    private let rowHeight: CGFloat = 24

    var body: some View {
        let items = viewModel.completionItems
        let visibleCount = min(items.count, maxVisible)

        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        completionRow(item, isSelected: index == viewModel.completionSelectedIndex)
                            .id(index)
                            .onTapGesture {
                                viewModel.completionSelectedIndex = index
                                if let text = viewModel.acceptCompletion() {
                                    insertCompletionText(text)
                                }
                            }
                    }
                }
            }
            .frame(
                width: 320,
                height: CGFloat(visibleCount) * rowHeight + 8
            )
            .onChange(of: viewModel.completionSelectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(AnvilColor.borderSubtle, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Code completions")
    }

    // MARK: - Row

    private func completionRow(_ item: CompletionItem, isSelected: Bool) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Kind icon
            Image(systemName: kindIcon(item.kind))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(kindColor(item.kind))
                .frame(width: 18, height: 18)
                .background(kindColor(item.kind).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .accessibilityHidden(true)

            // Label
            Text(item.label)
                .font(AnvilFont.code)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            Spacer()

            // Detail (type info)
            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .frame(height: rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.18) : .clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kindLabel(item.kind)), \(item.label)\(item.detail.map { ", \($0)" } ?? "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Insert

    private func insertCompletionText(_ text: String) {
        guard let file = viewModel.selectedFile,
              let fileIndex = viewModel.openFiles.firstIndex(where: { $0.id == file.id }) else { return }

        var lines = file.content.components(separatedBy: "\n")
        let lineIdx = viewModel.cursorLine - 1
        guard lineIdx >= 0, lineIdx < lines.count else { return }

        let line = lines[lineIdx]
        let col = viewModel.cursorColumn - 1

        // Find the word prefix at cursor to replace
        let prefixStart = line.index(line.startIndex, offsetBy: min(col, line.count))
        var wordStart = prefixStart
        while wordStart > line.startIndex {
            let prev = line.index(before: wordStart)
            let c = line[prev]
            if c.isLetter || c.isNumber || c == "_" {
                wordStart = prev
            } else {
                break
            }
        }

        // Replace the word prefix with the completion text
        let before = String(line[line.startIndex..<wordStart])
        let after = col < line.count ? String(line[prefixStart...]) : ""
        lines[lineIdx] = before + text + after

        let newContent = lines.joined(separator: "\n")
        let updated = EditorFile(
            name: file.name,
            path: file.path,
            content: newContent,
            language: file.language,
            relativePath: file.relativePath
        )
        viewModel.openFiles[fileIndex] = updated
        viewModel.selectedFileId = updated.id
        viewModel.cursorColumn = (before.count + text.count) + 1
    }

    // MARK: - Kind Mapping

    private func kindIcon(_ kind: CompletionItem.CompletionKind) -> String {
        switch kind {
        case .function, .method:    "f.cursive"
        case .variable, .field:     "v.circle"
        case .keyword:              "k.circle"
        case .classKind:            "c.circle"
        case .structKind:           "s.circle"
        case .interface:            "p.circle"
        case .property:             "p.circle.fill"
        case .enumKind, .enumMember: "e.circle"
        case .constant:             "number.circle"
        case .constructor:          "wrench"
        case .module:               "shippingbox"
        case .snippet:              "text.badge.plus"
        case .typeParameter:        "t.circle"
        case .file:                 "doc"
        case .folder:               "folder"
        case .operatorKind:         "plus.forwardslash.minus"
        default:                    "doc.text"
        }
    }

    private func kindColor(_ kind: CompletionItem.CompletionKind) -> Color {
        switch kind {
        case .function, .method:     AnvilColor.accentPurple
        case .variable, .field:      AnvilColor.accentBlue
        case .keyword:               AnvilColor.accentAmber
        case .classKind, .structKind, .interface: AnvilColor.accentTeal
        case .property:              AnvilColor.accentBlue
        case .enumKind, .enumMember: AnvilColor.accentGreen
        case .constant:              AnvilColor.accentAmber
        case .snippet:               AnvilColor.accentPurple
        default:                     AnvilColor.textSecondary
        }
    }

    private func kindLabel(_ kind: CompletionItem.CompletionKind) -> String {
        switch kind {
        case .function:    "Function"
        case .method:      "Method"
        case .variable:    "Variable"
        case .field:       "Field"
        case .keyword:     "Keyword"
        case .classKind:   "Class"
        case .structKind:  "Struct"
        case .interface:   "Protocol"
        case .property:    "Property"
        case .enumKind:    "Enum"
        case .enumMember:  "Enum Member"
        case .constant:    "Constant"
        case .constructor: "Constructor"
        case .module:      "Module"
        case .snippet:     "Snippet"
        default:           "Text"
        }
    }
}
