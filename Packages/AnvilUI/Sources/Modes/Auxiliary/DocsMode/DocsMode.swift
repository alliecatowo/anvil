import SwiftUI

struct DocsMode: View {
    @StateObject private var viewModel = DocsViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 0) {
            // Left: Document browser
            DocBrowser(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Right: Document editor with split preview
            DocEditor(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
        .onAppear {
            if let path = appState.currentProjectPath {
                viewModel.loadFromProject(path)
            }
        }
        .onChange(of: appState.currentProjectPath) { _, newPath in
            if let path = newPath {
                viewModel.loadFromProject(path)
            }
        }
    }
}
