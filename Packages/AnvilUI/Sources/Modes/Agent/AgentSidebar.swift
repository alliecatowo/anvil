import SwiftUI
import AnvilDomain

// MARK: - Agent Sidebar Tab

private enum AgentSidebarTab: String, CaseIterable, Hashable {
    case sessions = "Sessions"
    case dashboard = "Dashboard"

    var icon: String {
        switch self {
        case .sessions: "message"
        case .dashboard: "square.grid.2x2"
        }
    }
}

// MARK: - Agent Sidebar

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel
    @EnvironmentObject var container: DependencyContainer

    @State private var activeTab: AgentSidebarTab = .sessions

    // Search state
    @State private var searchQuery = ""
    @State private var searchResults: [SessionSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            AnvilSidebarHeaderRow(
                title: "Agent",
                icon: "bubble.left.and.text.bubble.right",
                count: viewModel.sessions.count
            ) {
                Button {
                    viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                    viewModel.showConversation()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityLabel("New Session")
                .accessibilityIdentifier("agent.sidebar.new-session")
            }

            AnvilSidebarSegmentedPicker(
                label: "Agent View",
                items: AgentSidebarTab.allCases.map {
                    AnvilSidebarSegmentedPicker<AgentSidebarTab>.SidebarPickerItem(
                        id: $0,
                        title: $0.rawValue,
                        icon: $0.icon
                    )
                },
                selection: $activeTab
            )
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.bottom, AnvilSpacing.xs)

            Divider()

            switch activeTab {
            case .sessions:
                sessionsSourceList
            case .dashboard:
                dashboardContent
            }
        }
        .onChange(of: viewModel.viewMode) { _, newMode in
            switch newMode {
            case .dashboard:
                activeTab = .dashboard
            case .conversation, .synthesisRoom:
                activeTab = .sessions
            }
        }
    }

    // MARK: - Sessions Source List

    @State private var selectedId: String?

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sessionsSourceList: some View {
        VStack(spacing: 0) {
            AnvilSidebarSearchBar(text: $searchQuery, placeholder: "Search sessions...")

            Divider()

            if isSearchActive {
                searchResultsList
            } else {
                sessionsList
            }
        }
        .onChange(of: searchQuery) { _, newQuery in
            searchTask?.cancel()
            let trimmed = newQuery.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else {
                searchResults = []
                isSearching = false
                return
            }
            isSearching = true
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                if let port = container.agentSessionPort {
                    let results = (try? await port.searchSessions(query: trimmed)) ?? []
                    guard !Task.isCancelled else { return }
                    searchResults = results
                } else {
                    // Fallback: filter local sessions by name
                    let q = trimmed.lowercased()
                    searchResults = viewModel.sessions
                        .filter { $0.displayName.lowercased().contains(q) }
                        .map { session in
                            SessionSearchResult(
                                sessionId: session.id,
                                sessionName: session.displayName,
                                excerpt: session.displayName,
                                date: session.lastActivityAt
                            )
                        }
                }
                isSearching = false
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        Group {
            if isSearching {
                VStack(spacing: AnvilSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text("No results for \"\(searchQuery)\"")
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    AnvilSidebarSection(title: "Results", icon: "magnifyingglass", count: searchResults.count) {
                        ForEach(searchResults) { result in
                            searchResultRow(result)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    navigateToSearchResult(result)
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private func searchResultRow(_ result: SessionSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(result.sessionName)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1)

            Text(result.excerpt)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(2)

            Text(result.date, style: .relative)
                .font(.system(size: 10))
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.vertical, AnvilSpacing.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(result.sessionName), \(result.excerpt)")
        .accessibilityAddTraits(.isButton)
    }

    private func navigateToSearchResult(_ result: SessionSearchResult) {
        searchQuery = ""
        searchResults = []
        viewModel.selectedSessionId = result.sessionId
        selectedId = result.sessionId
        viewModel.showConversation()
    }

    // MARK: - Session Tree

    /// Groups sessions into a parent-child hierarchy based on parentSessionId.
    private var sessionTree: [SessionTreeNode] {
        let allSessions = viewModel.sessions
        let childMap = Dictionary(grouping: allSessions.filter { $0.parentSessionId != nil }) { $0.parentSessionId! }
        let rootSessions = allSessions.filter { $0.parentSessionId == nil }

        return rootSessions.map { session in
            SessionTreeNode(
                session: session,
                children: childMap[session.id]?.map { child in
                    SessionTreeNode(session: child, children: [])
                } ?? []
            )
        }
    }

    // MARK: - Sessions List (non-search)

    private var sessionsList: some View {
        List(selection: $selectedId) {
            if !viewModel.synthesisRooms.isEmpty {
                AnvilSidebarSection(title: "Synthesis Rooms", icon: "arrow.triangle.merge", count: viewModel.synthesisRooms.count) {
                    ForEach(viewModel.synthesisRooms) { room in
                        synthesisRoomRow(room)
                            .tag(room.id)
                    }
                }
            }

            AnvilSidebarSection(title: "Sessions", icon: "message", count: viewModel.sessions.count) {
                ForEach(sessionTree) { node in
                    if node.children.isEmpty {
                        sessionRow(node.session)
                            .tag(node.session.id)
                    } else {
                        DisclosureGroup {
                            ForEach(node.children) { child in
                                childSessionRow(child.session)
                                    .tag(child.session.id)
                            }
                        } label: {
                            sessionRow(node.session)
                                .tag(node.session.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .onChange(of: selectedId) { _, newId in
            guard let id = newId else { return }
            Task { @MainActor in
                // Check if it's a synthesis room
                if viewModel.synthesisRooms.contains(where: { $0.id == id }) {
                    viewModel.showSynthesisRoom(id)
                } else {
                    viewModel.selectedSessionId = id
                    viewModel.showConversation()
                }
            }
        }
        .onChange(of: viewModel.selectedSessionId) { _, newId in
            Task { @MainActor in
                if viewModel.viewMode == .conversation {
                    selectedId = newId
                }
            }
        }
        .onAppear {
            selectedId = viewModel.selectedSessionId
        }
    }

    // MARK: - Child Session Row (compact, nested under parent)

    private func childSessionRow(_ session: AgentSession) -> some View {
        AnvilListItem(
            icon: session.isForked ? "arrow.triangle.branch" : sessionStatusIcon(session.status),
            title: session.displayName,
            subtitle: session.messages.last(where: { $0.role == .assistant })?.content.prefix(60).description,
            tag: session.status.rawValue.capitalized,
            tagColor: sessionStatusColor(session.status),
            timestamp: elapsedTime(from: session.startedAt, to: session.lastActivityAt, isRunning: session.status == .running),
            isSelected: viewModel.selectedSessionId == session.id,
            isCompact: false,
            indentLevel: 1
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Subagent \(session.displayName), \(session.status.rawValue)")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Open Session") {
                viewModel.selectedSessionId = session.id
                viewModel.showConversation()
            }
            Button("Export to Clipboard") {
                viewModel.exportSessionToClipboard(session.id)
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deleteSession(session.id)
            }
        }
    }

    /// Status dot for child sessions — uses pulse animation for running state per spec.
    @ViewBuilder
    private func childStatusDot(_ status: AgentSessionStatus) -> some View {
        switch status {
        case .running:
            ChildRunningDot()
        case .completed:
            Circle()
                .fill(AnvilColor.accentGreen)
                .frame(width: 6, height: 6)
        case .failed:
            Circle()
                .fill(AnvilColor.accentRed)
                .frame(width: 6, height: 6)
        case .paused:
            Circle()
                .fill(AnvilColor.accentAmber)
                .frame(width: 6, height: 6)
        case .idle:
            Circle()
                .stroke(AnvilColor.textTertiary, lineWidth: 1)
                .frame(width: 6, height: 6)
        case .cancelled:
            Circle()
                .stroke(AnvilColor.textTertiary, lineWidth: 1)
                .frame(width: 6, height: 6)
        }
    }

    // MARK: - Session Row

    private func sessionRow(_ session: AgentSession) -> some View {
        AnvilListItem(
            icon: session.isForked ? "arrow.triangle.branch" : sessionStatusIcon(session.status),
            title: session.displayName,
            subtitle: session.cost > 0 ? "\(elapsedTime(from: session.startedAt, to: session.lastActivityAt, isRunning: session.status == .running)) • \(formatCost(session.cost))" : elapsedTime(from: session.startedAt, to: session.lastActivityAt, isRunning: session.status == .running),
            tag: session.status.rawValue.capitalized,
            tagColor: sessionStatusColor(session.status),
            timestamp: session.isForked ? "forked" : nil,
            isSelected: viewModel.selectedSessionId == session.id,
            isCompact: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(session.displayName), \(session.status.rawValue)\(session.isForked ? ", forked" : "")")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Rename...") {
                viewModel.selectedSessionId = session.id
            }
            Button("Export to Clipboard") {
                viewModel.exportSessionToClipboard(session.id)
            }
            Divider()
            Button("Review with Critique Agent") {
                viewModel.dispatchCritiqueAgent(for: session.id)
            }
            Divider()
            Button("Delete", role: .destructive) {
                viewModel.deleteSession(session.id)
            }
        }
    }

    // MARK: - Synthesis Room Row

    private func synthesisRoomRow(_ room: SynthesisRoom) -> some View {
        AnvilListItem(
            icon: "arrow.triangle.merge",
            title: room.title,
            subtitle: room.status.rawValue.capitalized,
            tag: room.status.rawValue.capitalized,
            tagColor: synthesisStatusColor(room.status),
            isSelected: viewModel.selectedSessionId == room.id,
            isCompact: false
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.title), \(room.status.rawValue)")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Delete", role: .destructive) {
                viewModel.deleteSynthesisRoom(room.id)
            }
        }
    }

    // MARK: - Status Indicator

    private func sessionStatusIcon(_ status: AgentSessionStatus) -> String {
        switch status {
        case .running: "circle.fill"
        case .completed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .paused: "pause.circle.fill"
        case .idle: "circle"
        case .cancelled: "slash.circle"
        }
    }

    private func sessionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        case .idle, .cancelled: AnvilColor.textTertiary
        }
    }

    @ViewBuilder
    private func statusIndicator(_ status: AgentSessionStatus) -> some View {
        switch status {
        case .running:
            RunningIndicator()
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentGreen)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentRed)
        case .paused:
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.accentAmber)
        case .idle:
            Image(systemName: "circle")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary)
        case .cancelled:
            Image(systemName: "slash.circle")
                .font(.system(size: 12))
                .foregroundStyle(AnvilColor.textTertiary)
        }
    }

    private func sessionStatusBadge(_ status: AgentSessionStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .running: ("Running", AnvilColor.accentGreen)
            case .completed: ("Done", AnvilColor.accentBlue)
            case .failed: ("Failed", AnvilColor.accentRed)
            case .paused: ("Paused", AnvilColor.accentAmber)
            case .idle: ("Idle", AnvilColor.textTertiary)
            case .cancelled: ("Cancelled", AnvilColor.textTertiary)
            }
        }()
        return Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, AnvilSpacing.xs)
            .padding(.vertical, 1)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    // MARK: - Dashboard Content

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            // Summary stats
            VStack(spacing: AnvilSpacing.sm) {
                dashboardStat("Total Sessions", value: "\(viewModel.sessions.count)", icon: "message")
                dashboardStat("Running", value: "\(viewModel.sessions.filter { $0.status == .running }.count)", icon: "circle.fill", color: AnvilColor.accentGreen)
                dashboardStat("Total Cost", value: formatTotalCost(), icon: "dollarsign.circle")
            }
            .padding(AnvilSpacing.md)

            Divider()

            // Team roster
            if !viewModel.sessions.isEmpty {
                AnvilSidebarSectionHeader(
                    title: "Team Roster",
                    icon: "person.3",
                    count: Set(viewModel.sessions.map(\.model)).count
                )
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.top, AnvilSpacing.sm)

                TeamManagementView(viewModel: viewModel) { sessionId in
                    viewModel.selectedSessionId = sessionId
                    viewModel.showConversation()
                    activeTab = .sessions
                }
                .frame(maxHeight: 200)

                Divider()
            }

            // Session list overview
            List {
                ForEach(viewModel.sessions) { session in
                    HStack(spacing: AnvilSpacing.sm) {
                        statusIndicator(session.status)
                            .frame(width: 14)

                        Text(session.displayName)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        if session.cost > 0 {
                            Text(formatCost(session.cost))
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.textTertiary)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        viewModel.selectedSessionId = session.id
                        viewModel.showConversation()
                        activeTab = .sessions
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 10, bottom: 2, trailing: 8))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private func dashboardStat(_ label: String, value: String, icon: String, color: Color = AnvilColor.textSecondary) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)

            Spacer()

            Text(value)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(AnvilColor.textPrimary)
        }
    }

    // MARK: - Helpers

    private func synthesisStatusColor(_ status: SynthesisStatus) -> Color {
        switch status {
        case .pending: AnvilColor.textTertiary
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentPurple
        case .failed: AnvilColor.accentRed
        }
    }

    private func elapsedTime(from start: Date, to end: Date, isRunning: Bool) -> String {
        let reference = isRunning ? Date() : end
        let interval = reference.timeIntervalSince(start)
        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else {
            let hours = Int(interval / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    private func formatCost(_ cost: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 2
        return formatter.string(from: cost as NSDecimalNumber) ?? "$0.00"
    }

    private func formatTotalCost() -> String {
        let total = viewModel.sessions.reduce(Decimal.zero) { $0 + $1.cost }
        return formatCost(total)
    }
}

// MARK: - Session Tree Node

private struct SessionTreeNode: Identifiable {
    let session: AgentSession
    let children: [SessionTreeNode]

    var id: String { session.id }
}

// MARK: - Running Indicator (animated, parent rows)

private struct RunningIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        Circle()
            .fill(AnvilColor.accentGreen)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(AnvilColor.accentGreen.opacity(0.4), lineWidth: 2)
                    .scaleEffect(isAnimating ? 2.0 : 1.0)
                    .opacity(isAnimating ? 0.0 : 0.6)
            )
            .onAppear {
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
            .accessibilityLabel("Running")
    }
}

// MARK: - Child Running Dot (pulse opacity per spec)

private struct ChildRunningDot: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(AnvilColor.accentGreen)
            .frame(width: 6, height: 6)
            .opacity(isPulsing ? 1.0 : 0.6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .accessibilityLabel("Running")
    }
}
