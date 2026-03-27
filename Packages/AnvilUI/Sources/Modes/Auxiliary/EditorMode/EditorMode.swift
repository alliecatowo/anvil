import SwiftUI

struct EditorMode: View {
    @StateObject private var viewModel = EditorViewModel()
    @EnvironmentObject private var deps: DependencyContainer

    var body: some View {
        HStack(spacing: 0) {
            // Left: File tree sidebar
            EditorSidebar(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Center: Code editor
            VStack(spacing: 0) {
                EditorTabBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                BreadcrumbBar(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                EditorView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Right: Symbol outline (toggleable)
            if viewModel.isSymbolOutlineVisible {
                Divider().overlay(AnvilColor.borderSubtle)

                SymbolOutline(viewModel: viewModel)
                    .frame(width: 220)
                    .background(AnvilColor.backgroundSecondary)
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .onAppear {
            if viewModel.fileTree.isEmpty, let path = deps.currentProjectPath {
                viewModel.loadFileTree(from: path, using: deps.fileSystemService)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.toggleSymbolOutline()
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .foregroundStyle(
                            viewModel.isSymbolOutlineVisible
                                ? AnvilColor.accentBlue
                                : AnvilColor.textTertiary
                        )
                }
                .help("Toggle Symbol Outline")
            }
        }
    }
}
