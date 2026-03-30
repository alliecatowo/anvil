import SwiftUI
import AnvilTerminal

// MARK: - Utility Deck

/// Bottom panel available in all spaces, housing Terminal, Problems, and Output tabs.
struct UtilityDeck: View {
    @EnvironmentObject var appState: AppState
    @State private var isResizing = false
    @State private var activeTab: Tab = .terminal

    private let minHeight: CGFloat = 100
    private let maxHeight: CGFloat = 600

    enum Tab: String, CaseIterable {
        case terminal = "Terminal"
        case problems = "Problems"
        case output = "Output"
    }

    private var terminalVM: TerminalViewModel {
        appState.terminalViewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Resize handle
            resizeHandle

            // Deck header: tab picker + actions
            deckHeader

            Divider()

            // Tab content
            switch activeTab {
            case .terminal:
                terminalContent
            case .problems:
                utilityEmptyState("No Problems", icon: "checkmark.circle", message: "No issues detected.")
            case .output:
                utilityEmptyState("No Output", icon: "text.alignleft", message: "Build and task output will appear here.")
            }
        }
        .background(.regularMaterial)
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
            // Tab picker
            Picker("Utility", selection: $activeTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 240)

            // Terminal tabs (only when terminal tab is active)
            if activeTab == .terminal {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(terminalVM.sessions) { session in
                            terminalTabView(session)
                        }
                    }
                }
                .padding(.leading, AnvilSpacing.sm)
            }

            Spacer()

            // Actions
            HStack(spacing: AnvilSpacing.xs) {
                if activeTab == .terminal {
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
                    .accessibilityLabel("New Terminal")
                    .accessibilityAddTraits(.isButton)
                }

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
                .accessibilityLabel("Close Utility Deck")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.trailing, AnvilSpacing.sm)
        }
        .frame(height: 28)
        .padding(.horizontal, AnvilSpacing.sm)
    }

    private func terminalTabView(_ session: TerminalSession) -> some View {
        let isSelected = terminalVM.selectedSessionId == session.id

        return HStack(spacing: 2) {
            Button {
                terminalVM.selectTab(session.id)
            } label: {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9))
                    Text(session.title)
                        .font(AnvilFont.label)
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xxs)
                .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if terminalVM.sessions.count > 1 {
                Button {
                    terminalVM.closeTab(session.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(AnvilColor.textTertiary)
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

    // MARK: - Terminal Content

    private var terminalContent: some View {
        TerminalView(viewModel: terminalVM)
            .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Empty State

    private func utilityEmptyState(_ title: String, icon: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: icon)
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
