import SwiftUI
import AnvilDomain

struct ShipMode: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ShipModeContent(viewModel: appState.shipViewModel)
            .background(.background)
    }
}
