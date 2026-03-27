import SwiftUI
import AnvilDomain

struct ReviewMode: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ReviewModeContent(viewModel: appState.reviewViewModel)
            .background(AnvilColor.backgroundPrimary)
    }
}
