import SwiftUI
import AnvilApplication

public struct StatusBar: View {
    @EnvironmentObject var appState: AppState
    @State private var isBranchPickerVisible = false

    public init() {}

    public var body: some View {
        HStack(spacing: AnvilSpacing.md) {
            // Left: Project name (click to switch)
            Button {
                appState.toggleProjectSwitcher()
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                    Text(appState.currentProject?.name ?? "No Project")
                        .font(AnvilFont.statusBar)
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Switch Project (\u{2318}\u{21E7}O)")

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            // Branch + source control (clickable for branch picker)
            Button {
                isBranchPickerVisible.toggle()
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10))
                    Text(appState.currentBranch)
                        .font(AnvilFont.statusBar)

                    if appState.uncommittedFileCount > 0 {
                        Text("\(appState.uncommittedFileCount)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentAmber)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Image(systemName: "chevron.up")
                        .font(.system(size: 8, weight: .medium))
                }
                .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Switch Branch")
            .popover(isPresented: $isBranchPickerVisible, arrowEdge: .top) {
                BranchPicker(isPresented: $isBranchPickerVisible)
            }

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            Spacer()

            // Center: Agent activity indicator
            AgentActivityIndicator()

            Spacer()

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            // Cursor position (visible in editor-like modes)
            CursorPositionIndicator()

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            // File encoding + line ending
            EncodingIndicator()

            LineEndingIndicator()

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            // Right: Cost + time
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "dollarsign.circle")
                    .font(.system(size: 10))
                Text(formatCost(appState.sessionCost))
                    .font(AnvilFont.statusBar)
                Text("/")
                    .foregroundStyle(AnvilColor.textTertiary)
                Text(formatCost(appState.todayCost))
                    .font(AnvilFont.statusBar)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .foregroundStyle(AnvilColor.textSecondary)

            Circle()
                .fill(AnvilColor.textTertiary.opacity(0.3))
                .frame(width: 3, height: 3)

            // Settings gear
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
                    .foregroundStyle(AnvilColor.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: AnvilSpacing.statusBarHeight)
        .background(.bar)
    }

    private func formatCost(_ cost: Decimal) -> String {
        "$\(NSDecimalNumber(decimal: cost).doubleValue.formatted(.number.precision(.fractionLength(2))))"
    }
}

// MARK: - Agent Activity Indicator

struct AgentActivityIndicator: View {
    @EnvironmentObject var appState: AppState
    @State private var elapsedSeconds: Int = 0
    @State private var timerTask: Task<Void, Never>?

    private var isRunning: Bool {
        appState.agentStatus == "Running"
    }

    var body: some View {
        Button {
            navigateToActiveSession()
        } label: {
            HStack(spacing: AnvilSpacing.xs) {
                // Status indicator: spinner when running, dot otherwise
                if isRunning {
                    AnvilLoadingIndicator(size: 10)
                } else {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                }

                // Status text + tool name
                if isRunning {
                    if let tool = appState.agentCurrentTool {
                        Text(formatToolName(tool))
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.accentGreen)
                            .lineLimit(1)
                    } else {
                        Text("Thinking...")
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.accentGreen)
                    }

                    // Elapsed time
                    Text(formatElapsed(elapsedSeconds))
                        .font(AnvilFont.statusBar)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .monospacedDigit()
                } else {
                    Text(appState.agentStatus)
                        .font(AnvilFont.statusBar)
                        .foregroundStyle(AnvilColor.textSecondary)
                }
            }
            .padding(.horizontal, isRunning ? 6 : 0)
            .padding(.vertical, isRunning ? 2 : 0)
            .background(
                isRunning
                    ? AnvilColor.accentGreen.opacity(0.08)
                    : .clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.borderless)
        .help(isRunning ? "Click to view active session" : "Agent \(appState.agentStatus.lowercased())")
        .onChange(of: appState.agentRunStartedAt) { _, newValue in
            if newValue != nil {
                startTimer()
            } else {
                stopTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var statusColor: Color {
        switch appState.agentStatus {
        case "Failed": AnvilColor.accentRed
        default: AnvilColor.textTertiary
        }
    }

    private func navigateToActiveSession() {
        guard let sessionId = appState.agentActiveSessionId ?? appState.agentViewModel.selectedSessionId else { return }
        appState.agentViewModel.selectedSessionId = sessionId
        appState.switchMode(.agent)
    }

    private func formatToolName(_ name: String) -> String {
        // Convert snake_case tool names to readable form
        name.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    private func startTimer() {
        stopTimer()
        elapsedSeconds = 0
        timerTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if let startedAt = appState.agentRunStartedAt {
                    elapsedSeconds = Int(Date.now.timeIntervalSince(startedAt))
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        elapsedSeconds = 0
    }
}

// MARK: - Cursor Position Indicator

struct CursorPositionIndicator: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button {
            appState.isGoToLineVisible = true
        } label: {
            HStack(spacing: AnvilSpacing.xs) {
                Text("Ln \(appState.cursorLine), Col \(appState.cursorColumn)")
                    .font(AnvilFont.statusBar)
                    .monospacedDigit()

                if appState.selectionCount > 0 {
                    Text("(\(appState.selectionCount) selected)")
                        .font(AnvilFont.statusBar)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            }
            .foregroundStyle(AnvilColor.textSecondary)
        }
        .buttonStyle(.borderless)
        .help("Go to Line (Ctrl+G)")
        .popover(isPresented: $appState.isGoToLineVisible, arrowEdge: .top) {
            GoToLinePopover()
        }
    }
}

// MARK: - Go To Line Popover

struct GoToLinePopover: View {
    @EnvironmentObject var appState: AppState
    @State private var lineText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: AnvilSpacing.sm) {
            Text("Go to Line")
                .font(AnvilFont.sidebarHeader)
                .foregroundStyle(.primary)

            HStack(spacing: AnvilSpacing.xs) {
                TextField("Line number", text: $lineText)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.statusBar)
                    .focused($isFocused)
                    .onSubmit {
                        goToLine()
                    }

                Button("Go") {
                    goToLine()
                }
                .buttonStyle(.bordered)
                .font(AnvilFont.statusBar)
            }

            Text("Current: Ln \(appState.cursorLine)")
                .font(AnvilFont.label)
                .foregroundStyle(.tertiary)
        }
        .padding(AnvilSpacing.md)
        .frame(width: 200)
        .onAppear {
            lineText = ""
            isFocused = true
        }
        .onKeyPress(.escape) {
            appState.isGoToLineVisible = false
            return .handled
        }
    }

    private func goToLine() {
        guard let line = Int(lineText), line > 0 else { return }
        appState.cursorLine = line
        appState.cursorColumn = 1
        appState.selectionCount = 0
        appState.pendingSymbolLine = line
        appState.isGoToLineVisible = false
    }
}

// MARK: - Encoding Indicator

struct EncodingIndicator: View {
    @EnvironmentObject var appState: AppState
    @State private var isPickerVisible = false

    var body: some View {
        Button {
            isPickerVisible.toggle()
        } label: {
            Text(appState.fileEncoding.rawValue)
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.textSecondary)
        }
        .buttonStyle(.borderless)
        .help("File Encoding")
        .popover(isPresented: $isPickerVisible, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Encoding")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)

                List(FileEncoding.allCases, id: \.self) { encoding in
                    Button {
                        appState.fileEncoding = encoding
                        isPickerVisible = false
                    } label: {
                        HStack {
                            Text(encoding.rawValue)
                                .font(AnvilFont.sidebarItem)
                            Spacer()
                            if encoding == appState.fileEncoding {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .frame(width: 180)
            .frame(maxHeight: 250)
        }
    }
}

// MARK: - Line Ending Indicator

struct LineEndingIndicator: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Button {
            cycleLineEnding()
        } label: {
            Text(appState.lineEnding.rawValue)
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.textSecondary)
        }
        .buttonStyle(.borderless)
        .help("Line Ending (click to toggle)")
    }

    private func cycleLineEnding() {
        let all = LineEnding.allCases
        guard let idx = all.firstIndex(of: appState.lineEnding) else { return }
        let next = all[(idx + 1) % all.count]
        appState.lineEnding = next
    }
}
