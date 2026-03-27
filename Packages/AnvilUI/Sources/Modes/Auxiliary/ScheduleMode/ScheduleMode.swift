import SwiftUI
import AnvilDomain

struct ScheduleMode: View {
    @StateObject private var viewModel = ScheduleViewModel()

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: agenda list
            VStack(spacing: 0) {
                tabSelector
                Divider().overlay(AnvilColor.borderSubtle)

                Group {
                    switch viewModel.selectedTab {
                    case .agenda:
                        AgendaView(viewModel: viewModel)
                    case .blocks:
                        TimeBlockView(viewModel: viewModel)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ScheduleTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(AnvilFont.label)
                        .foregroundStyle(
                            viewModel.selectedTab == tab
                                ? AnvilColor.textPrimary
                                : AnvilColor.textTertiary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnvilSpacing.sm)
                        .background(
                            viewModel.selectedTab == tab
                                ? AnvilColor.backgroundTertiary
                                : Color.clear
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }
}
