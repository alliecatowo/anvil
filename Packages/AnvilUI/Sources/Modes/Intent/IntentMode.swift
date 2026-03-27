import SwiftUI
import AnvilDomain

struct IntentMode: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        IntentModeContent(viewModel: appState.intentViewModel)
            .background(AnvilColor.backgroundPrimary)
    }
}
