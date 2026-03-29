import SwiftUI

/// The Docs content area — just the detail/editor pane.
/// Navigation (DocBrowser) lives in LibrarySidebar, using appState.libraryDocsViewModel.
struct DocsMode: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        DocEditor(viewModel: appState.libraryDocsViewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                if let path = appState.currentProjectPath {
                    appState.libraryDocsViewModel.loadFromProject(path)
                }
            }
            .onChange(of: appState.currentProjectPath) { _, newPath in
                if let path = newPath {
                    appState.libraryDocsViewModel.loadFromProject(path)
                }
            }
    }
}
