import SwiftUI
import AnvilDomain

// MARK: - Agent Sidebar

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel
    @EnvironmentObject var container: DependencyContainer

    // Search state
    @State private var searchQuery = ""
    @State private var searchResults: [SessionSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        sessionsSourceList
    }

    // MARK: - Sessions Source List

    @State private var selectedId: String?

    private var isSearchActive: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sessionsSourceList: some View {
        VStack(spacing: 0) {
            // Search + new session
            HStack(spacing: AnvilSpacing.xs) {
                AnvilSidebarSearchBar(text: $searchQuery, placeholder: "Search sessions...")

                Button {
                    viewModel.startNewSession(prompt: "", model: viewModel.selectedModelId)
                    viewModel.showConversation()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityLabel("New Session")
                .accessibilityIdentifier("agent.sidebar.new-session")
                .padding(.trailing, AnvilSpacing.md)
            }
            .padding(.vertical, AnvilSpacing.xs)

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
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Searching...")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searchQuery)\"")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    AnvilSidebarSection(title: "Results", icon: "magnifyingglass", count: searchResults.count) {
                        ForEach(searchResults) { result in
                            Button {
                                navigateToSearchResult(result)
                            } label: {
                                searchResultRow(result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private func searchResultRow(_ result: SessionSearchResult) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.tertiary)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.sessionName)
                    .font(.body)
                    .lineLimit(1)
                Text(result.excerpt)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(result.date, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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
        .scrollContentBackground(.hidden)
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

    // MARK: - Session Row

    private func sessionRow(_ session: AgentSession) -> some View {
        let subtitle: String = {
            var parts: [String] = []
            let elapsed = elapsedTime(from: session.startedAt, to: session.lastActivityAt, isRunning: session.status == .running)
            parts.append(elapsed)
            if session.cost > 0 {
                parts.append(formatCost(session.cost))
            }
            return parts.joined(separator: " \u{2022} ")
        }()

        return HStack(spacing: 8) {
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if session.isForked {
                Text("forked")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
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

    // MARK: - Child Session Row (compact, nested under parent)

    private func childSessionRow(_ session: AgentSession) -> some View {
        let subtitle = session.messages.last(where: { $0.role == .assistant })?.content.prefix(60).description

        return HStack(spacing: 8) {
            Circle()
                .fill(sessionStatusColor(session.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayName)
                    .font(.body)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(elapsedTime(from: session.startedAt, to: session.lastActivityAt, isRunning: session.status == .running))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
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

    // MARK: - Synthesis Room Row

    private func synthesisRoomRow(_ room: SynthesisRoom) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(synthesisStatusColor(room.status))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(room.title)
                    .font(.body)
                    .lineLimit(1)
                Text(room.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(room.title), \(room.status.rawValue)")
        .accessibilityAddTraits(.isButton)
        .contextMenu {
            Button("Delete", role: .destructive) {
                viewModel.deleteSynthesisRoom(room.id)
            }
        }
    }

    // MARK: - Status Helpers

    private func sessionStatusColor(_ status: AgentSessionStatus) -> Color {
        switch status {
        case .running: .green
        case .completed: Color.accentColor
        case .failed: .red
        case .paused: .orange
        case .idle, .cancelled: Color.secondary
        }
    }

    private func synthesisStatusColor(_ status: SynthesisStatus) -> Color {
        switch status {
        case .pending: Color.secondary
        case .running: .green
        case .completed: .purple
        case .failed: .red
        }
    }

    // MARK: - Helpers

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
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .overlay(
                Circle()
                    .stroke(Color.green.opacity(0.4), lineWidth: 2)
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
