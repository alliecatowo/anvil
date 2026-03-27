import SwiftUI

// MARK: - InlineEditBar

/// The floating ⌘K inline edit overlay.
/// Anchors to a specific line in the editor and shows:
///   1. Prompt phase: text field + model badge
///   2. Generating phase: spinner with streaming text
///   3. Review phase: side-by-side diff + accept/reject actions
struct InlineEditBar: View {
    @ObservedObject var viewModel: EditorViewModel

    @FocusState private var isPromptFocused: Bool
    @State private var appeared = false

    private let lineHeight: CGFloat = 20
    private let barHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.inlineEditPhase {
            case .hidden:
                EmptyView()

            case .prompting:
                promptBar
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                    ))

            case .generating:
                generatingBar
                    .transition(.opacity)

            case .reviewing:
                if let diff = viewModel.inlineEditDiff {
                    reviewBar(diff: diff)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
        .animation(AnvilAnimation.standard, value: viewModel.inlineEditPhase)
        .onAppear {
            if viewModel.inlineEditPhase == .prompting {
                isPromptFocused = true
            }
            withAnimation(.easeOut(duration: 0.12)) {
                appeared = true
            }
        }
        .onChange(of: viewModel.inlineEditPhase) { _, phase in
            if phase == .prompting {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isPromptFocused = true
                }
            }
        }
    }

    // MARK: - Prompt Bar

    private var promptBar: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // AI spark icon
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 20)

            // Prompt field
            TextField("Edit with AI... (↵ to apply, esc to cancel)", text: $viewModel.inlineEditPrompt)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AnvilColor.textPrimary)
                .focused($isPromptFocused)
                .onSubmit {
                    viewModel.submitInlineEdit()
                }

            // Model badge
            Text("claude-sonnet")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AnvilColor.accentPurple.opacity(0.8))
                .padding(.horizontal, AnvilSpacing.xs)
                .padding(.vertical, 2)
                .background(AnvilColor.accentPurple.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // Cancel
            Button {
                viewModel.cancelInlineEdit()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Cancel (esc)")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: barHeight)
        .background(.ultraThinMaterial)
        .background(AnvilColor.backgroundElevated.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnvilColor.accentPurple.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
        .onKeyPress(.escape) {
            viewModel.cancelInlineEdit()
            return .handled
        }
    }

    // MARK: - Generating Bar

    private var generatingBar: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Pulsing purple orb
            Circle()
                .fill(AnvilColor.accentPurple)
                .frame(width: 8, height: 8)
                .modifier(PulsingModifier())

            Text("Generating edit...")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            // Stop button
            Button {
                viewModel.cancelInlineEdit()
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                    Text("Stop")
                        .font(.system(size: 11))
                }
                .foregroundStyle(AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.xs)
                .padding(.vertical, 3)
                .background(AnvilColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: barHeight)
        .background(.ultraThinMaterial)
        .background(AnvilColor.backgroundElevated.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnvilColor.accentPurple.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 4)
    }

    // MARK: - Review Bar

    private func reviewBar(diff: InlineEditDiff) -> some View {
        VStack(spacing: 0) {
            // Header: prompt recap + actions
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnvilColor.accentPurple)

                Text(viewModel.inlineEditPrompt)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AnvilColor.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Stats
                let added = countChangedLines(diff: diff).added
                let removed = countChangedLines(diff: diff).removed
                if added > 0 {
                    Text("+\(added)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AnvilColor.accentGreen)
                }
                if removed > 0 {
                    Text("-\(removed)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AnvilColor.accentRed)
                }

                Divider()
                    .frame(height: 14)
                    .overlay(AnvilColor.borderSubtle)

                // Accept button
                Button {
                    viewModel.acceptInlineEdit()
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Accept")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AnvilColor.accentGreen)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.return, modifiers: [])
                .help("Accept edit (↵)")

                // Reject button
                Button {
                    viewModel.rejectInlineEdit()
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .medium))
                        Text("Reject")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(AnvilColor.textSecondary)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Reject edit (esc)")

                // Cancel entirely
                Button {
                    viewModel.cancelInlineEdit()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .frame(height: barHeight)

            Divider().overlay(AnvilColor.borderSubtle)

            // Diff body
            diffContent(diff: diff)
        }
        .background(.ultraThinMaterial)
        .background(AnvilColor.backgroundElevated.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnvilColor.borderMedium, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, y: 6)
        .onKeyPress(.escape) {
            viewModel.rejectInlineEdit()
            return .handled
        }
    }

    // MARK: - Diff Content

    private func diffContent(diff: InlineEditDiff) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let changes = computeDiffLines(original: diff.originalLines, proposed: diff.proposedLines)
            ForEach(Array(changes.enumerated()), id: \.offset) { _, change in
                diffLine(change)
            }
        }
        .padding(.vertical, AnvilSpacing.xxs)
    }

    private func diffLine(_ change: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Change indicator
            Text(change.kind.prefix)
                .font(AnvilFont.code)
                .foregroundStyle(change.kind.foreground)
                .frame(width: 20, alignment: .center)
                .background(change.kind.background.opacity(0.15))

            // Line content
            Text(change.text)
                .font(AnvilFont.code)
                .foregroundStyle(change.kind == .context ? AnvilColor.textSecondary : change.kind.foreground)
                .padding(.leading, AnvilSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(change.kind.background)
        }
        .frame(height: 20)
    }

    // MARK: - Diff Computation

    private struct DiffLine {
        enum Kind {
            case added, removed, context

            var prefix: String {
                switch self {
                case .added: return "+"
                case .removed: return "-"
                case .context: return " "
                }
            }
            var foreground: Color {
                switch self {
                case .added: return AnvilColor.diffAddedText
                case .removed: return AnvilColor.diffRemovedText
                case .context: return AnvilColor.textTertiary
                }
            }
            var background: Color {
                switch self {
                case .added: return AnvilColor.diffAddedBackground
                case .removed: return AnvilColor.diffRemovedBackground
                case .context: return .clear
                }
            }
        }
        let text: String
        let kind: Kind
    }

    private func computeDiffLines(original: [String], proposed: [String]) -> [DiffLine] {
        var result: [DiffLine] = []

        // Simple LCS-based diff for small line counts (editor selections are typically < 50 lines)
        let lcs = longestCommonSubsequence(original, proposed)
        var i = 0, j = 0, k = 0

        while i < original.count || j < proposed.count {
            if k < lcs.count {
                let (li, lj) = lcs[k]
                // Emit removed lines before LCS match
                while i < li {
                    result.append(DiffLine(text: original[i], kind: .removed))
                    i += 1
                }
                // Emit added lines before LCS match
                while j < lj {
                    result.append(DiffLine(text: proposed[j], kind: .added))
                    j += 1
                }
                // Emit context line
                result.append(DiffLine(text: original[i], kind: .context))
                i += 1; j += 1; k += 1
            } else {
                // Past LCS: all remaining are removes then adds
                while i < original.count {
                    result.append(DiffLine(text: original[i], kind: .removed))
                    i += 1
                }
                while j < proposed.count {
                    result.append(DiffLine(text: proposed[j], kind: .added))
                    j += 1
                }
                break
            }
        }

        return result
    }

    /// O(n*m) LCS returning matched index pairs. Fine for short line counts.
    private func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [(Int, Int)] {
        let n = a.count, m = b.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 1...max(n, 1) where i <= n {
            for j in 1...max(m, 1) where j <= m {
                dp[i][j] = a[i-1] == b[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }
        // Backtrack
        var pairs: [(Int, Int)] = []
        var i = n, j = m
        while i > 0 && j > 0 {
            if a[i-1] == b[j-1] {
                pairs.append((i-1, j-1))
                i -= 1; j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        return pairs.reversed()
    }

    private func countChangedLines(diff: InlineEditDiff) -> (added: Int, removed: Int) {
        let changes = computeDiffLines(original: diff.originalLines, proposed: diff.proposedLines)
        let added = changes.filter { $0.kind == .added }.count
        let removed = changes.filter { $0.kind == .removed }.count
        return (added, removed)
    }
}

// MARK: - Pulsing Animation

private struct PulsingModifier: ViewModifier {
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(pulsing ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

// MARK: - InlineEditOverlay

/// Wraps an editor content view with the inline edit bar positioned at the active line.
/// Usage: wrap the ScrollView content in EditorView with this overlay.
struct InlineEditOverlay: View {
    @ObservedObject var viewModel: EditorViewModel
    let lineHeight: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            if viewModel.inlineEditPhase != .hidden {
                let targetLine = viewModel.inlineEditSelectedRange.lowerBound
                let rawY = CGFloat(targetLine - 1) * lineHeight
                // Position just below the selected line block
                let barY = rawY + lineHeight * CGFloat(viewModel.inlineEditSelectedRange.count) + 6
                // Keep within visible area
                let clampedY = min(barY, geo.size.height - 300)

                InlineEditBar(viewModel: viewModel)
                .padding(.horizontal, AnvilSpacing.xl)
                .offset(y: clampedY)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(viewModel.inlineEditPhase != .hidden)
    }
}
