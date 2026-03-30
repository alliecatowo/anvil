import SwiftUI
import AnvilTerminal

// MARK: - Utility Deck

/// Bottom panel — a pure terminal drawer with session tabs.
struct UtilityDeck: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var terminalVM: TerminalViewModel
    @State private var isResizing = false
    /// Maps a primary session ID to its split partner session ID.
    @State private var splitPairs: [UUID: UUID] = [:]

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 600

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
            // Clean up any split pairs where the partner was deleted
            for (primary, partner) in splitPairs where !newIds.contains(partner) {
                splitPairs.removeValue(forKey: primary)
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
            HStack(spacing: AnvilSpacing.sm) {
                Button { toggleSplit() } label: {
                    Image(systemName: isCurrentSplit ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                        .font(.system(size: 11))
                        .foregroundStyle(isCurrentSplit ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(isCurrentSplit ? "Close Split" : "Split Terminal")

                Button {
                    terminalVM.addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("New Terminal")

                Button {
                    withAnimation { appState.isTerminalPanelVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Close Terminal")
            }
            .padding(.trailing, AnvilSpacing.md)
        }
        .frame(height: 28)
        .padding(.leading, AnvilSpacing.sm)
        .background(.bar)
    }

    // MARK: - Terminal Tab

    private func terminalTab(_ session: TerminalSession) -> some View {
        let isSelected = terminalVM.selectedSessionId == session.id
        let hasSplit = splitPairs[session.id] != nil
        let tabTitle = session.title

        return HStack(spacing: 0) {
            // Tab content (clickable to select)
            Button {
                terminalVM.selectTab(session.id)
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))

                    Text(tabTitle)
                        .font(AnvilFont.label)
                        .lineLimit(1)

                    // Split indicator
                    if hasSplit {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            // Close button — always visible if multiple tabs
            if terminalVM.sessions.count > 1 {
                Button {
                    // Clean up split pairs involving this session
                    splitPairs.removeValue(forKey: session.id)
                    for (k, v) in splitPairs where v == session.id { splitPairs.removeValue(forKey: k) }
                    terminalVM.closeTab(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.title)\(isSelected ? ", selected" : "")\(hasSplit ? ", split" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// The split partner for the currently selected session, if any.
    private var currentSplitId: UUID? {
        guard let selectedId = terminalVM.selectedSessionId else { return nil }
        return splitPairs[selectedId]
    }

    /// Whether the currently selected session has a split.
    private var isCurrentSplit: Bool {
        currentSplitId != nil
    }

    // MARK: - Split Toggle

    private func toggleSplit() {
        guard let selectedId = terminalVM.selectedSessionId else { return }
        if splitPairs[selectedId] != nil {
            // Close split — remove the partner mapping
            splitPairs.removeValue(forKey: selectedId)
        } else {
            // Create split — new session becomes the partner
            let newSession = terminalVM.addTab()
            // Switch back to the original tab (addTab auto-selects the new one)
            terminalVM.selectTab(selectedId)
            splitPairs[selectedId] = newSession.id
        }
    }

    // MARK: - Terminal Content

    private var terminalContent: some View {
        Group {
            if let splitId = currentSplitId {
                HSplitView {
                    TerminalView(viewModel: terminalVM)
                    TerminalView(viewModel: terminalVM, sessionOverrideId: splitId)
                }
            } else {
                TerminalView(viewModel: terminalVM)
            }
        }
    }
}
