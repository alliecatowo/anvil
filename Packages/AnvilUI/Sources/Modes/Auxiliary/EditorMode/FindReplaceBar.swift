import SwiftUI

struct FindReplaceBar: View {
    @ObservedObject var viewModel: EditorViewModel
    @FocusState private var isFindFocused: Bool
    @State private var isReplaceExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Find row
            HStack(spacing: AnvilSpacing.xs) {
                // Expand/collapse replace
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        isReplaceExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isReplaceExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .help("Toggle Replace")

                // Find input
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(AnvilColor.textTertiary)

                    TextField("Find", text: $viewModel.findText)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .focused($isFindFocused)
                        .onSubmit { viewModel.findNext() }

                    if !viewModel.findText.isEmpty {
                        Button {
                            viewModel.findText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AnvilSpacing.xs)
                .padding(.vertical, 3)
                .background(AnvilColor.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFindFocused ? AnvilColor.accentBlue : AnvilColor.borderSubtle,
                            lineWidth: 1
                        )
                )
                .frame(minWidth: 200, maxWidth: 300)

                // Match count
                if !viewModel.findText.isEmpty {
                    Text(matchCountLabel)
                        .font(AnvilFont.label)
                        .foregroundStyle(
                            viewModel.findMatches.isEmpty
                                ? AnvilColor.accentRed
                                : AnvilColor.textTertiary
                        )
                        .frame(minWidth: 60)
                }

                // Prev / Next
                Button { viewModel.findPrevious() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnvilColor.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(AnvilColor.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Previous Match (Shift+Enter)")
                .disabled(viewModel.findMatches.isEmpty)

                Button { viewModel.findNext() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnvilColor.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(AnvilColor.backgroundTertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .help("Next Match (Enter)")
                .disabled(viewModel.findMatches.isEmpty)

                Divider()
                    .frame(height: 16)
                    .overlay(AnvilColor.borderSubtle)

                // Toggle buttons: match case, whole word, regex
                toggleButton(
                    icon: "textformat",
                    label: "Match Case",
                    isActive: $viewModel.findMatchCase
                )

                toggleButton(
                    icon: "textformat.abc.dottedunderline",
                    label: "Whole Word",
                    isActive: $viewModel.findWholeWord
                )

                toggleButton(
                    icon: "ellipsis.curlybraces",
                    label: "Regex",
                    isActive: $viewModel.findUseRegex
                )

                Spacer()

                // Close
                Button { viewModel.closeFindBar() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Close (Escape)")
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            // Replace row (expandable)
            if isReplaceExpanded {
                HStack(spacing: AnvilSpacing.xs) {
                    // Spacer to align with find input
                    Color.clear.frame(width: 16, height: 1)

                    // Replace input
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.textTertiary)

                        TextField("Replace", text: $viewModel.replaceText)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .onSubmit { viewModel.replaceCurrent() }
                    }
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 3)
                    .background(AnvilColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AnvilColor.borderSubtle, lineWidth: 1)
                    )
                    .frame(minWidth: 200, maxWidth: 300)

                    // Replace / Replace All
                    Button { viewModel.replaceCurrent() } label: {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AnvilColor.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(AnvilColor.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Replace")
                    .disabled(viewModel.findMatches.isEmpty)

                    Button { viewModel.replaceAll() } label: {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AnvilColor.textSecondary)
                            .frame(width: 22, height: 22)
                            .background(AnvilColor.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(
                                Text("All")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundStyle(AnvilColor.textTertiary)
                                    .offset(x: 5, y: 5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Replace All")
                    .disabled(viewModel.findMatches.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(AnvilColor.backgroundSecondary)
        .onAppear {
            isFindFocused = true
        }
    }

    // MARK: - Helpers

    private var matchCountLabel: String {
        if viewModel.findMatches.isEmpty {
            return "No results"
        }
        return "\(viewModel.currentMatchIndex + 1) of \(viewModel.findMatches.count)"
    }

    private func toggleButton(icon: String, label: String, isActive: Binding<Bool>) -> some View {
        Button {
            isActive.wrappedValue.toggle()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isActive.wrappedValue ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                .frame(width: 22, height: 22)
                .background(isActive.wrappedValue ? AnvilColor.accentBlue.opacity(0.15) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
