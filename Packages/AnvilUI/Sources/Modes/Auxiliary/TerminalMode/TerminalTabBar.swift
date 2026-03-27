import SwiftUI

struct TerminalTabBar: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.tabs) { tab in
                        tabItem(tab)
                    }
                }
            }

            Spacer()

            // Add tab button
            Button {
                viewModel.addTab()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AnvilSpacing.sm)
        }
        .frame(height: 32)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Tab Item

    private func tabItem(_ tab: TerminalTab) -> some View {
        let isSelected = viewModel.selectedTabId == tab.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: tab.icon)
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)

            Text(tab.name)
                .font(AnvilFont.label)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            if viewModel.tabs.count > 1 {
                Button {
                    viewModel.closeTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: 32)
        .background(isSelected ? AnvilColor.backgroundTertiary : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? AnvilColor.accentBlue : Color.clear)
                .frame(height: 2),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectTab(tab.id)
        }
    }
}
