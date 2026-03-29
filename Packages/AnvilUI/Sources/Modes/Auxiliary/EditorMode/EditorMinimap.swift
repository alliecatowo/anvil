import SwiftUI
import AnvilEditor

/// Minimap: a scaled-down overview of the full file on the right edge of the editor.
/// Syntax-colored using existing SyntaxHighlighter token data.
/// Includes a draggable viewport indicator and click-to-scroll.
struct EditorMinimap: View {
    @ObservedObject var viewModel: EditorViewModel

    private let minimapWidth: CGFloat = 80
    private let lineScale: CGFloat = 2    // height per minimap line
    private let charScale: CGFloat = 1.2  // width per character

    private var syntaxHighlighter: SyntaxHighlighter {
        let ext = viewModel.selectedFile?.name.components(separatedBy: ".").last ?? ""
        let lang = SyntaxHighlighter.language(forExtension: ext)
        return SyntaxHighlighter(language: lang)
    }

    var body: some View {
        GeometryReader { geometry in
            let lines = fileLines
            let totalMinimapHeight = CGFloat(lines.count) * lineScale
            let visibleLines = Int(geometry.size.height / 20) // 20pt per editor line
            let viewportHeight = max(CGFloat(visibleLines) * lineScale, 20)

            ZStack(alignment: .topLeading) {
                // Minimap content
                Canvas { context, size in
                    drawMinimap(context: context, size: size, lines: lines)
                }
                .frame(width: minimapWidth, height: max(totalMinimapHeight, geometry.size.height))

                // Viewport indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(AnvilColor.textPrimary.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(AnvilColor.textSecondary.opacity(0.25), lineWidth: 1)
                    )
                    .frame(width: minimapWidth, height: viewportHeight)
                    .offset(y: viewportOffset(
                        totalLines: lines.count,
                        visibleLines: visibleLines,
                        containerHeight: geometry.size.height,
                        totalMinimapHeight: totalMinimapHeight
                    ))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(
                                    y: value.location.y,
                                    totalLines: lines.count,
                                    containerHeight: geometry.size.height,
                                    totalMinimapHeight: totalMinimapHeight
                                )
                            }
                    )
            }
            .frame(width: minimapWidth, height: geometry.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleDrag(
                    y: location.y,
                    totalLines: lines.count,
                    containerHeight: geometry.size.height,
                    totalMinimapHeight: totalMinimapHeight
                )
            }
        }
        .frame(width: minimapWidth)
        .background(AnvilColor.backgroundSecondary.opacity(0.5))
        .accessibilityLabel("Code minimap")
        .accessibilityHint("Click or drag to scroll the editor")
    }

    // MARK: - File Lines

    private var fileLines: [String] {
        viewModel.selectedFile?.content.components(separatedBy: "\n") ?? []
    }

    // MARK: - Canvas Drawing

    private func drawMinimap(context: GraphicsContext, size: CGSize, lines: [String]) {
        let highlighter = syntaxHighlighter

        for (index, line) in lines.enumerated() {
            let y = CGFloat(index) * lineScale
            guard y < size.height + lineScale else { break }

            let tokens = highlighter.tokenize(line)
            var x: CGFloat = 2 // small left margin

            for token in tokens {
                let width = CGFloat(token.text.count) * charScale
                guard x + width <= minimapWidth else { break }

                let color = minimapColor(for: token.kind)
                let rect = CGRect(x: x, y: y, width: width, height: lineScale - 0.5)
                context.fill(Path(rect), with: .color(color))
                x += width
            }
        }
    }

    private func minimapColor(for kind: SyntaxTokenKind) -> Color {
        switch kind {
        case .keyword:      AnvilColor.accentPurple.opacity(0.7)
        case .type:         AnvilColor.accentTeal.opacity(0.7)
        case .string:       AnvilColor.accentGreen.opacity(0.7)
        case .number:       AnvilColor.accentAmber.opacity(0.7)
        case .comment:      AnvilColor.textTertiary.opacity(0.4)
        case .function:     AnvilColor.accentBlue.opacity(0.7)
        case .property:     AnvilColor.accentBlue.opacity(0.5)
        case .operator:     AnvilColor.textSecondary.opacity(0.5)
        case .preprocessor: AnvilColor.accentAmber.opacity(0.6)
        case .attribute:    AnvilColor.accentPurple.opacity(0.5)
        case .plain:        AnvilColor.textPrimary.opacity(0.3)
        }
    }

    // MARK: - Viewport Positioning

    private func viewportOffset(
        totalLines: Int,
        visibleLines: Int,
        containerHeight: CGFloat,
        totalMinimapHeight: CGFloat
    ) -> CGFloat {
        guard totalLines > visibleLines, totalLines > 0 else { return 0 }
        let scrollFraction = CGFloat(viewModel.cursorLine - 1) / CGFloat(totalLines)
        let maxOffset = max(containerHeight - max(CGFloat(visibleLines) * lineScale, 20), 0)
        return scrollFraction * maxOffset
    }

    // MARK: - Interaction

    private func handleDrag(
        y: CGFloat,
        totalLines: Int,
        containerHeight: CGFloat,
        totalMinimapHeight: CGFloat
    ) {
        guard totalLines > 0, containerHeight > 0 else { return }
        let fraction = max(0, min(1, y / max(totalMinimapHeight, containerHeight)))
        let targetLine = Int(fraction * CGFloat(totalLines)) + 1
        viewModel.cursorLine = min(max(targetLine, 1), totalLines)
    }
}
