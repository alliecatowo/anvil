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
                        .foregroundStyle(.tertiary)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isReplaceExpanded ? "Collapse Replace" : "Expand Replace")
                .accessibilityAddTraits(.isToggle)
                .help("Toggle Replace")

                // Find input
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)

                    TextField("Find", text: $viewModel.findText)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.code)
                        .focused($isFindFocused)
                        .onSubmit { viewModel.findNext() }
                        .accessibilityLabel("Find text")

                    if !viewModel.findText.isEmpty {
                        Button {
                            viewModel.findText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear find text")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .padding(.horizontal, AnvilSpacing.xs)
                .padding(.vertical, 3)
                .background(.background, in: RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isFindFocused ? AnvilColor.accentBlue : Color.secondary.opacity(0.3),
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
                                : Color.secondary
                        )
                        .frame(minWidth: 60)
                }

                // Prev / Next
                Button { viewModel.findPrevious() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Previous Match")
                .accessibilityAddTraits(.isButton)
                .help("Previous Match (Shift+Enter)")
                .disabled(viewModel.findMatches.isEmpty)

                Button { viewModel.findNext() } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Next Match")
                .accessibilityAddTraits(.isButton)
                .help("Next Match (Enter)")
                .disabled(viewModel.findMatches.isEmpty)

                Divider()
                    .frame(height: 16)

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
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Find Bar")
                .accessibilityAddTraits(.isButton)
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
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)

                        TextField("Replace", text: $viewModel.replaceText)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)
                            .onSubmit { viewModel.replaceCurrent() }
                            .accessibilityLabel("Replace text")
                    }
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 3)
                    .background(.background, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .frame(minWidth: 200, maxWidth: 300)

                    // Replace / Replace All
                    Button { viewModel.replaceCurrent() } label: {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Replace Current Match")
                    .accessibilityAddTraits(.isButton)
                    .help("Replace")
                    .disabled(viewModel.findMatches.isEmpty)

                    Button { viewModel.replaceAll() } label: {
                        Label("All", systemImage: "arrow.turn.down.left")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityLabel("Replace All Matches")
                    .accessibilityAddTraits(.isButton)
                    .help("Replace All")
                    .disabled(viewModel.findMatches.isEmpty)

                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(.bar)
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
                .foregroundStyle(isActive.wrappedValue ? AnvilColor.accentBlue : Color.secondary)
                .frame(width: 22, height: 22)
                .background(isActive.wrappedValue ? AnvilColor.accentBlue.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isActive.wrappedValue ? "On" : "Off")
        .help(label)
    }
}
