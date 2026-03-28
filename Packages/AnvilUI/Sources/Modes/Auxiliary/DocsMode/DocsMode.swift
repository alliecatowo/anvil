import SwiftUI

struct DocsMode: View {
    @StateObject private var viewModel = DocsViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            DocBrowser(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 340)
        } detail: {
            DocEditor(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .background(.background)
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
