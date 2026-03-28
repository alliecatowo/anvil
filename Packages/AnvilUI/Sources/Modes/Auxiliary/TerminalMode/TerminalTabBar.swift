import SwiftUI
import AnvilTerminal

struct TerminalTabBar: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.sessions) { session in
                        tabItem(session)
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
            .accessibilityLabel("New Terminal Tab")
            .accessibilityAddTraits(.isButton)
            .padding(.horizontal, AnvilSpacing.sm)
        }
        .frame(height: 32)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Tab Item

    private func tabItem(_ session: TerminalSession) -> some View {
        let isSelected = viewModel.selectedSessionId == session.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? AnvilColor.accentBlue : AnvilColor.textTertiary)

            Text(session.title)
                .font(AnvilFont.label)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            if !session.isRunning {
                Circle()
                    .fill(AnvilColor.textTertiary)
                    .frame(width: 6, height: 6)
            }

            if viewModel.sessions.count > 1 {
                Button {
                    viewModel.closeTab(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close \(session.title)")
                .accessibilityAddTraits(.isButton)
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
            viewModel.selectTab(session.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title)\(isSelected ? ", selected" : ""), \(session.isRunning ? "running" : "exited")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
