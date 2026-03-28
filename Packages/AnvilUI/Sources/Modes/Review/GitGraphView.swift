import SwiftUI
import AnvilDomain
import AnvilGit

// MARK: - GitGraphView

/// GitKraken-style commit graph visualization. Renders a DAG of commits
/// with branch topology lanes, branch labels, and a commit detail panel.
struct GitGraphView: View {
    let graph: GitGraphBuilder.CommitGraph
    /// Map of commit hash → branch names that point to it
    var branchLabels: [String: [String]] = [:]
    var headHash: String?

    @State private var selectedNodeIndex: Int? = nil

    private static let rowHeight: CGFloat = 32
    private static let laneWidth: CGFloat = 16
    private static let graphMinWidth: CGFloat = 48
    private static let dotRadius: CGFloat = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13))
                    .foregroundStyle(AnvilColor.textTertiary)
                Text("Commit Graph")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)
                Spacer()
                Text("\(graph.nodes.count) commits")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            if graph.nodes.isEmpty {
                AnvilEmptyState(
                    icon: "arrow.triangle.branch",
                    title: "No commits",
                    message: "Open a git repository to view commit history."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(graph.nodes.enumerated()), id: \.offset) { index, node in
                            commitRow(node: node, index: index)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Commit Row

    @ViewBuilder
    private func commitRow(node: GitGraphBuilder.GraphNode, index: Int) -> some View {
        let isSelected = selectedNodeIndex == index
        let nextNode: GitGraphBuilder.GraphNode? = index + 1 < graph.nodes.count ? graph.nodes[index + 1] : nil
        let prevNode: GitGraphBuilder.GraphNode? = index > 0 ? graph.nodes[index - 1] : nil

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Graph lane canvas
                graphLane(node: node, prevNode: prevNode, nextNode: nextNode)
                    .frame(width: graphWidth, height: Self.rowHeight)
                    .accessibilityHidden(true)

                // Commit info
                commitInfo(node: node, isSelected: isSelected)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: Self.rowHeight)
            .background(isSelected ? AnvilColor.selectionBackground : Color.clear)
            .contentShape(Rectangle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(node.commit.message.components(separatedBy: "\n").first ?? node.commit.message), by \(node.commit.author), \(relativeDate(node.commit.date))")
            .accessibilityAddTraits(.isButton)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedNodeIndex = selectedNodeIndex == index ? nil : index
                }
            }

            // Inline detail panel
            if isSelected {
                commitDetail(node: node)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
        }
    }

    // MARK: - Graph Lane Canvas

    private func graphLane(
        node: GitGraphBuilder.GraphNode,
        prevNode: GitGraphBuilder.GraphNode?,
        nextNode: GitGraphBuilder.GraphNode?
    ) -> some View {
        Canvas { context, size in
            let col = node.column
            let maxCols = max(graph.maxColumns, col + 1)
            let centerY = size.height / 2

            // Draw active lane lines (vertical continuations for all active columns)
            // We approximate active columns by looking at prev/next node columns
            let activeColumns = activeLaneColumns(node: node, prevNode: prevNode, nextNode: nextNode)

            for laneCol in activeColumns {
                let x = laneX(laneCol, maxCols: maxCols, width: size.width)
                let color = laneColor(laneCol)

                // Skip the current node's column — we'll draw special lines there
                if laneCol == col { continue }

                // Straight vertical line through this row
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }

            // Draw lines from this node to its parent columns
            for (parentIndex, parentHash) in node.parents.enumerated() {
                let parentCol = parentColumn(for: parentHash, from: node, nodeIndex: indexOf(node))
                let thisX = laneX(col, maxCols: maxCols, width: size.width)
                let parentX = laneX(parentCol, maxCols: maxCols, width: size.width)
                let color = laneColor(parentIndex == 0 ? col : parentCol)

                var path = Path()
                if parentIndex == 0 {
                    // First parent: line going down from node center
                    path.move(to: CGPoint(x: thisX, y: centerY))
                    if parentCol == col {
                        // Straight down
                        path.addLine(to: CGPoint(x: thisX, y: size.height))
                    } else {
                        // Curve to parent column
                        let midY = size.height * 0.75
                        path.addCurve(
                            to: CGPoint(x: parentX, y: size.height),
                            control1: CGPoint(x: thisX, y: midY),
                            control2: CGPoint(x: parentX, y: midY)
                        )
                    }
                } else {
                    // Merge parent: curve from node center to parent column
                    path.move(to: CGPoint(x: thisX, y: centerY))
                    let midY = size.height * 0.8
                    path.addCurve(
                        to: CGPoint(x: parentX, y: size.height),
                        control1: CGPoint(x: thisX, y: midY),
                        control2: CGPoint(x: parentX, y: midY)
                    )
                }
                context.stroke(path, with: .color(color), lineWidth: 1.5)
            }

            // Draw line from top to this node (from previous row)
            let thisX = laneX(col, maxCols: maxCols, width: size.width)
            let nodeColor = laneColor(col)

            if prevNode != nil {
                // Check if any previous node routes through this column
                let incomingCol = incomingColumnFromAbove(node: node, prevNode: prevNode)
                if let incoming = incomingCol {
                    let fromX = laneX(incoming, maxCols: maxCols, width: size.width)
                    var path = Path()
                    path.move(to: CGPoint(x: fromX, y: 0))
                    if incoming == col {
                        path.addLine(to: CGPoint(x: thisX, y: centerY))
                    } else {
                        let midY = size.height * 0.25
                        path.addCurve(
                            to: CGPoint(x: thisX, y: centerY),
                            control1: CGPoint(x: fromX, y: midY),
                            control2: CGPoint(x: thisX, y: midY)
                        )
                    }
                    context.stroke(path, with: .color(nodeColor), lineWidth: 1.5)
                } else {
                    // Straight line from top on this column
                    var path = Path()
                    path.move(to: CGPoint(x: thisX, y: 0))
                    path.addLine(to: CGPoint(x: thisX, y: centerY))
                    context.stroke(path, with: .color(nodeColor), lineWidth: 1.5)
                }
            }

            // Draw commit circle
            let dotRect = CGRect(
                x: thisX - Self.dotRadius,
                y: centerY - Self.dotRadius,
                width: Self.dotRadius * 2,
                height: Self.dotRadius * 2
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(nodeColor))

            // HEAD indicator — extra ring
            if node.isHead {
                let ringRect = dotRect.insetBy(dx: -2, dy: -2)
                context.stroke(Path(ellipseIn: ringRect), with: .color(nodeColor), lineWidth: 1.5)
            }
        }
    }

    // MARK: - Commit Info

    private func commitInfo(node: GitGraphBuilder.GraphNode, isSelected: Bool) -> some View {
        HStack(spacing: AnvilSpacing.xs) {
            // Branch / HEAD labels
            let labels = commitLabels(for: node)
            if !labels.isEmpty {
                HStack(spacing: 3) {
                    ForEach(labels, id: \.self) { label in
                        branchBadge(label, isHead: label == "HEAD")
                    }
                }
            }

            // Short hash
            Text(node.commit.shortHash)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 52, alignment: .leading)

            // Message
            Text(node.commit.message.components(separatedBy: "\n").first ?? node.commit.message)
                .font(AnvilFont.sidebarItem)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            // Author
            Text(node.commit.author.components(separatedBy: " ").first ?? node.commit.author)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .lineLimit(1)
                .frame(width: 60, alignment: .trailing)

            // Relative date
            Text(relativeDate(node.commit.date))
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.trailing, AnvilSpacing.md)
    }

    // MARK: - Commit Detail

    private func commitDetail(node: GitGraphBuilder.GraphNode) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Divider()

            VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                // Full message
                Text(node.commit.message)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)

                Divider()

                Grid(alignment: .leading, horizontalSpacing: AnvilSpacing.lg, verticalSpacing: AnvilSpacing.xxs) {
                    detailRow("Hash", value: node.commit.id)
                    detailRow("Author", value: "\(node.commit.author) <\(node.commit.authorEmail)>")
                    detailRow("Date", value: absoluteDate(node.commit.date))
                    if node.commit.filesChanged > 0 {
                        detailRow(
                            "Changed",
                            value: "\(node.commit.filesChanged) file\(node.commit.filesChanged == 1 ? "" : "s")  +\(node.commit.insertions) -\(node.commit.deletions)"
                        )
                    }
                    if node.commit.parents.count > 1 {
                        detailRow("Merge", value: node.commit.parents.prefix(2).map { String($0.prefix(7)) }.joined(separator: " ← "))
                    }
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)
        }
        .background(.background.secondary)
    }

    private func detailRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Text(value)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    // MARK: - Helpers

    private func branchBadge(_ name: String, isHead: Bool) -> some View {
        Text(name)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(isHead ? .white : AnvilColor.accentBlue)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(isHead ? AnvilColor.accentGreen : AnvilColor.accentBlue.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .accessibilityLabel("Branch: \(name)")
    }

    private func commitLabels(for node: GitGraphBuilder.GraphNode) -> [String] {
        var labels: [String] = []
        if node.isHead { labels.append("HEAD") }
        if let branches = branchLabels[node.commit.id] {
            labels.append(contentsOf: branches)
        }
        return labels
    }

    private var graphWidth: CGFloat {
        let cols = max(graph.maxColumns, 1)
        return max(Self.graphMinWidth, CGFloat(cols) * Self.laneWidth + Self.laneWidth)
    }

    private func laneX(_ col: Int, maxCols: Int, width: CGFloat) -> CGFloat {
        let step = min(Self.laneWidth, width / CGFloat(max(maxCols, 1)))
        return step * CGFloat(col) + step / 2
    }

    /// Colors for each lane column — cycling through a GitKraken-style palette.
    private func laneColor(_ col: Int) -> Color {
        let palette: [Color] = [
            AnvilColor.accentBlue,
            AnvilColor.accentPurple,
            AnvilColor.accentGreen,
            AnvilColor.accentAmber,
            AnvilColor.accentRed,
            Color(red: 0.2, green: 0.8, blue: 0.8),  // teal
            Color(red: 0.9, green: 0.5, blue: 0.2),  // orange
            Color(red: 0.7, green: 0.3, blue: 0.9),  // violet
        ]
        return palette[col % palette.count]
    }

    /// Return the column index of a parent hash, looking ahead in the graph.
    private func parentColumn(for parentHash: String, from node: GitGraphBuilder.GraphNode, nodeIndex: Int) -> Int {
        // Search for the parent in subsequent nodes
        for i in (nodeIndex + 1)..<graph.nodes.count {
            if graph.nodes[i].commit.id == parentHash {
                return graph.nodes[i].column
            }
        }
        // Default: same column (first parent continuation)
        return node.column
    }

    /// Find the index of a node in the graph.
    private func indexOf(_ node: GitGraphBuilder.GraphNode) -> Int {
        graph.nodes.firstIndex(where: { $0.commit.id == node.commit.id }) ?? 0
    }

    /// Determine which column this node's incoming line comes from (from the row above).
    /// Returns nil if straight-in on the same column.
    private func incomingColumnFromAbove(node: GitGraphBuilder.GraphNode, prevNode: GitGraphBuilder.GraphNode?) -> Int? {
        guard let prev = prevNode else { return nil }
        // If prev's first parent == this node, the line comes straight from prev's column
        if prev.parents.first == node.commit.id && prev.column != node.column {
            return prev.column
        }
        return nil
    }

    /// Approximate active columns (lanes that are "in flight") for a given row.
    private func activeLaneColumns(
        node: GitGraphBuilder.GraphNode,
        prevNode: GitGraphBuilder.GraphNode?,
        nextNode: GitGraphBuilder.GraphNode?
    ) -> Set<Int> {
        var cols = Set<Int>()
        // Columns of nodes that appear before and after — simple approximation
        if let prev = prevNode { cols.insert(prev.column) }
        if let next = nextNode { cols.insert(next.column) }
        cols.insert(node.column)
        return cols
    }

    // MARK: - Date Formatting

    private func relativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60: return "now"
        case ..<3600: return "\(Int(interval / 60))m"
        case ..<86400: return "\(Int(interval / 3600))h"
        case ..<604800: return "\(Int(interval / 86400))d"
        case ..<2592000: return "\(Int(interval / 604800))w"
        default: return "\(Int(interval / 2592000))mo"
        }
    }

    private func absoluteDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - GitGraphContainerView

/// Container that loads commits via the git adapter and builds the graph.
struct GitGraphContainerView: View {
    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appState: AppState

    @State private var graph: GitGraphBuilder.CommitGraph = GitGraphBuilder.CommitGraph(nodes: [], maxColumns: 0)
    @State private var branchLabels: [String: [String]] = [:]
    @State private var headHash: String?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: AnvilSpacing.md) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Loading commit history...")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                AnvilEmptyState(
                    icon: "exclamationmark.triangle",
                    title: "Could not load commits",
                    message: error
                )
            } else {
                GitGraphView(graph: graph, branchLabels: branchLabels, headHash: headHash)
            }
        }
        .task {
            await loadGraph()
        }
    }

    private func loadGraph() async {
        guard let adapter = container.getOrCreateGitAdapter() else {
            // No git adapter — show sample data for demo
            graph = GitGraphView.sampleGraph()
            branchLabels = ["abc1234": ["main", "HEAD"]]
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Load commits from HEAD (all reachable history, up to 200)
            let commits = try await adapter.commits(branch: "HEAD", limit: 200)

            // HEAD hash is the first commit in the log
            headHash = commits.first?.id

            // Build graph
            let builder = GitGraphBuilder()
            graph = builder.buildGraph(from: commits, headRef: headHash)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sample Data

extension GitGraphView {
    /// Sample graph for previews and when no git adapter is available.
    static func sampleGraph() -> GitGraphBuilder.CommitGraph {
        let now = Date()
        let commits = [
            Commit(id: "abc1234", shortHash: "abc1234", author: "allie", authorEmail: "allie@anvil.dev",
                   date: now, message: "feat: add git graph visualization", parents: ["def5678"],
                   filesChanged: 3, insertions: 240, deletions: 12),
            Commit(id: "def5678", shortHash: "def5678", author: "allie", authorEmail: "allie@anvil.dev",
                   date: now.addingTimeInterval(-3600), message: "fix: inline edit anchorY param mismatch",
                   parents: ["ghi9012", "jkl3456"],
                   filesChanged: 1, insertions: 0, deletions: 4),
            Commit(id: "jkl3456", shortHash: "jkl3456", author: "alex", authorEmail: "alex@anvil.dev",
                   date: now.addingTimeInterval(-7200), message: "feat: synthesis rooms in agent mode",
                   parents: ["ghi9012"],
                   filesChanged: 5, insertions: 180, deletions: 20),
            Commit(id: "ghi9012", shortHash: "ghi9012", author: "allie", authorEmail: "allie@anvil.dev",
                   date: now.addingTimeInterval(-14400), message: "chore: update project config",
                   parents: ["mno6789"],
                   filesChanged: 2, insertions: 10, deletions: 5),
            Commit(id: "mno6789", shortHash: "mno6789", author: "allie", authorEmail: "allie@anvil.dev",
                   date: now.addingTimeInterval(-86400), message: "feat: AI inline edit ⌘K",
                   parents: ["pqr0123"],
                   filesChanged: 4, insertions: 320, deletions: 45),
            Commit(id: "pqr0123", shortHash: "pqr0123", author: "alex", authorEmail: "alex@anvil.dev",
                   date: now.addingTimeInterval(-172800), message: "feat: session memory (.anvil/memory.md)",
                   parents: [],
                   filesChanged: 2, insertions: 95, deletions: 0),
        ]
        let builder = GitGraphBuilder()
        return builder.buildGraph(from: commits, headRef: "abc1234")
    }
}
