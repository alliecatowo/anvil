import SwiftUI

struct TerminalPanel: View {
    @EnvironmentObject var appState: AppState
    @State private var isResizing = false

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 600

    private var terminalVM: TerminalViewModel {
        appState.terminalViewModel
    }

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
            .onHover { inside in
                if inside {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
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
                    .fill(isResizing ? AnvilColor.accentBlue : AnvilColor.borderSubtle)
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
                    ForEach(terminalVM.tabs) { tab in
                        terminalTabView(tab)
                    }
                }
            }

            Spacer()

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                // New terminal
                Button {
                    terminalVM.addTab()
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

    private func terminalTabView(_ tab: TerminalTab) -> some View {
        let isSelected = terminalVM.selectedTabId == tab.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: tab.icon)
                .font(.system(size: 9))
            Text(tab.name)
                .font(AnvilFont.label)
                .lineLimit(1)

            // Close tab button
            if terminalVM.tabs.count > 1 {
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
            terminalVM.selectTab(tab.id)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let tab = terminalVM.selectedTab {
                VStack(spacing: 0) {
                    // Terminal output
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(tab.lines) { line in
                                    Text(line.content)
                                        .font(AnvilFont.code)
                                        .foregroundStyle(line.style.color)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, AnvilSpacing.md)
                                        .padding(.vertical, 1)
                                        .id(line.id)
                                }
                            }
                            .padding(.vertical, AnvilSpacing.xs)
                        }
                        .onChange(of: tab.lines.count) { _, _ in
                            if let lastId = tab.lines.last?.id {
                                proxy.scrollTo(lastId, anchor: .bottom)
                            }
                        }
                    }

                    // Input bar
                    HStack(spacing: AnvilSpacing.xs) {
                        Text("$")
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.accentGreen)

                        TextField("", text: Binding(
                            get: { terminalVM.inputText },
                            set: { terminalVM.inputText = $0 }
                        ))
                        .textFieldStyle(.plain)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .onSubmit {
                            terminalVM.submitInput()
                        }
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.backgroundPrimary)
                }
            } else {
                Text("No terminal session")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }
}
