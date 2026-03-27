import SwiftUI

struct TerminalMode: View {
    @StateObject private var viewModel = TerminalViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TerminalTabBar(viewModel: viewModel)

            Divider().overlay(AnvilColor.borderSubtle)

            TerminalView(viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(hex: 0x0A0A0A))
    }
}
