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
                        .overlay(AnvilColor.borderSubtle)
                        .padding(.horizontal, 4)

                    Button {
                        onClose?()
                    } label: {
                        Image(systemName: "xmark.square")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.textTertiary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Close Split")
                    .padding(.trailing, AnvilSpacing.xs)
                }
            }

            Divider().overlay(AnvilColor.borderSubtle)

            BreadcrumbBar(viewModel: viewModel)

            Divider().overlay(AnvilColor.borderSubtle)

            // Find & Replace bar
            if viewModel.isFindBarVisible {
                FindReplaceBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)
            }

            // Read-only banner
            if viewModel.isSelectedFileReadOnly {
                ReadOnlyBanner(viewModel: viewModel)
            }

            EditorView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isActive ? AnvilColor.accentBlue.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onFocus()
        }
    }
}
