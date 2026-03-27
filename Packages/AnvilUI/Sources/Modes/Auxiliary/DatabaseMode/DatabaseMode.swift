import SwiftUI

struct DatabaseMode: View {
    @StateObject private var viewModel = DatabaseViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left: Schema explorer
            SchemaExplorer(viewModel: viewModel)
                .frame(width: AnvilSpacing.sidebarWidth)
                .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Right: Query console + results
            VStack(spacing: 0) {
                QueryConsole(viewModel: viewModel)

                Divider().overlay(AnvilColor.borderSubtle)

                ResultsTable(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
