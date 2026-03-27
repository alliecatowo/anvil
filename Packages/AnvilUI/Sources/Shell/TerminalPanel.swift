import SwiftUI

struct TerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var isResizing = false

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 600

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandle

            // Tab bar + controls
            panelHeader

            Divider().overlay(AnvilColor.borderSubtle)

            // Terminal content
            terminalContent
        }
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 4)
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        isResizing = true
                        let newHeight = appState.terminalPanelHeight - value.translation.height
                        appState.terminalPanelHeight = max(minHeight, min(maxHeight, newHeight))
                    }
                    .onEnded { _ in
                        isResizing = false
                    }
            )
            .overlay(
                Rectangle()
                    .fill(isResizing ? AnvilColor.accentBlue : Color.clear)
                    .frame(height: 1)
                    .frame(maxWidth: .infinity),
                alignment: .center
            )
    }

    // MARK: - Panel Header

    private var panelHeader: some View {
        HStack(spacing: 0) {
            // Terminal tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(appState.terminalTabs) { tab in
                        terminalTab(tab)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                // New terminal
                Button {
                    appState.addTerminalTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textSecondary)
                }
                .buttonStyle(.borderless)
                .help("New Terminal")

                // Close panel
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        appState.isTerminalPanelVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.borderless)
                .help("Close Panel (\u{2318}J)")
            }
            .padding(.trailing, AnvilSpacing.sm)
        }
        .frame(height: 28)
        .background(AnvilColor.backgroundSecondary)
    }

    private func terminalTab(_ tab: TerminalTab) -> some View {
        let isSelected = appState.selectedTerminalTabId == tab.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: "terminal.fill")
                .font(.system(size: 9))
            Text(tab.name)
                .font(AnvilFont.label)
                .lineLimit(1)

            // Close tab button (show on hover or when selected)
            if appState.terminalTabs.count > 1 {
                Button {
                    appState.closeTerminalTab(tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textTertiary)
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xxs)
        .background(isSelected ? AnvilColor.backgroundPrimary : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectedTerminalTabId = tab.id
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        ZStack {
            AnvilColor.backgroundPrimary

            if let selectedTab = appState.terminalTabs.first(where: { $0.id == appState.selectedTerminalTabId }) {
                VStack(alignment: .leading, spacing: 0) {
                    // Simulated terminal prompt
                    HStack(spacing: 0) {
                        Text("~/project")
                            .foregroundStyle(AnvilColor.accentBlue)
                        Text(" on ")
                            .foregroundStyle(AnvilColor.textTertiary)
                        Text(appState.currentBranch)
                            .foregroundStyle(AnvilColor.accentPurple)
                        Text(" \u{276F} ")
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                    .font(AnvilFont.code)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.top, AnvilSpacing.sm)

                    Spacer()

                    // Placeholder hint
                    Text("Terminal (\(selectedTab.shellPath)) — real shell integration coming soon")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()
                }
            } else {
                Text("No terminal session")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
    }
}

// MARK: - Cursor Modifier

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
