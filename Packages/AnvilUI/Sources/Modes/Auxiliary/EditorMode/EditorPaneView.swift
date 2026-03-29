import SwiftUI

/// A single editor pane with its own tab bar, breadcrumb, find bar, and code view.
/// Used both as the sole pane and as one half of a split.
struct EditorPaneView: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var splitState: SplitEditorState
    let paneId: UUID
    let isActive: Bool
    let onFocus: () -> Void
    let onClose: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Pane header: tab bar + optional close button
            HStack(spacing: 0) {
                EditorTabBar(viewModel: viewModel)

                if onClose != nil {
                    Divider()
                        .frame(height: 20)
                        .padding(.horizontal, 4)

                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.square")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Split Pane")
                    .accessibilityAddTraits(.isButton)
                    .help("Close Split")
                    .padding(.trailing, AnvilSpacing.xs)
                }
            }

            Divider()

            BreadcrumbBar(viewModel: viewModel)

            Divider()

            // Find & Replace bar
            if viewModel.isFindBarVisible {
                FindReplaceBar(viewModel: viewModel)

                Divider()
            }

            // Read-only banner
            if viewModel.isSelectedFileReadOnly {
                ReadOnlyBanner(viewModel: viewModel)
            }

            HStack(spacing: 0) {
                EditorView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if viewModel.isMinimapVisible, viewModel.selectedFile != nil {
                    Divider()
                    EditorMinimap(viewModel: viewModel)
                }
            }
        }
        .background(.background)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? AnvilColor.accentBlue.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
        .accessibilityLabel(isActive ? "Active editor pane" : "Editor pane")
        .accessibilityAddTraits(.isButton)
    }
}
