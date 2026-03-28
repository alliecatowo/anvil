import SwiftUI
import AnvilDomain

struct IntentMode: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        IntentModeContent(viewModel: appState.intentViewModel)
            .background(.background)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Intent mode")
    }
}
