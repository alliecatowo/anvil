import SwiftUI
import AnvilTerminal

// MARK: - Utility Deck

/// Bottom panel — a pure terminal drawer with session tabs.
struct UtilityDeck: View {
    @EnvironmentObject var appState: AppState
    @State private var isResizing = false
    @State private var splitSessionId: UUID? = nil

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 600

    private var terminalVM: TerminalViewModel {
        appState.terminalViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandle

            // Deck header: terminal tabs + actions
            deckHeader

            Divider()

            // Terminal content
            terminalContent
        }
        .onChange(of: terminalVM.sessions.map(\.id)) { _, newIds in
            // Clear split if the split session was deleted
            if let splitId = splitSessionId, !newIds.contains(splitId) {
                splitSessionId = nil
            }
        }
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

    // MARK: - Deck Header

    private var deckHeader: some View {
        HStack(spacing: 0) {
            // Terminal session tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(terminalVM.sessions) { session in
                        terminalTab(session)
                    }
                }
            }

            Spacer()

            // Actions: split, new, close
            HStack(spacing: AnvilSpacing.xs) {
                Button { toggleSplit() } label: {
                    Image(systemName: splitSessionId != nil ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(splitSessionId != nil ? Color.accentColor : .secondary)
                .help(splitSessionId != nil ? "Close Split" : "Split Terminal")

                Button { terminalVM.addTab() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("New Terminal")

                Button {
                    withAnimation { appState.isTerminalPanelVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .medium))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.tertiary)
                .help("Close Terminal")
            }
            .padding(.trailing, AnvilSpacing.sm)
        }
        .frame(height: 28)
        .padding(.leading, AnvilSpacing.sm)
        .background(.bar)
    }

    // MARK: - Terminal Tab

    private func terminalTab(_ session: TerminalSession) -> some View {
        let isSelected = terminalVM.selectedSessionId == session.id
        let tabTitle: String = {
            if let splitId = splitSessionId,
               terminalVM.selectedSessionId == session.id,
               let splitSession = terminalVM.sessions.first(where: { $0.id == splitId }) {
                return "\(session.title) | \(splitSession.title)"
            }
            return session.title
        }()

        return HStack(spacing: 2) {
            Button {
                terminalVM.selectTab(session.id)
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))
                    Text(tabTitle)
                        .font(AnvilFont.label)
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? .primary : .tertiary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if terminalVM.sessions.count > 1 && isSelected {
                Button {
                    terminalVM.closeTab(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 14, height: 14)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title)\(isSelected ? ", selected" : ""), \(session.isRunning ? "running" : "exited")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
    }

    // MARK: - Split Toggle

    private func toggleSplit() {
        if splitSessionId != nil {
            splitSessionId = nil
        } else {
            let newSession = terminalVM.addTab()
            splitSessionId = newSession.id
        }
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let splitId = splitSessionId {
                HSplitView {
                    TerminalView(viewModel: terminalVM)
                        .background(AnvilColor.backgroundPrimary)
                    TerminalView(viewModel: terminalVM, sessionOverrideId: splitId)
                        .background(AnvilColor.backgroundPrimary)
                }
            } else {
                TerminalView(viewModel: terminalVM)
                    .background(AnvilColor.backgroundPrimary)
            }
        }
    }
}
