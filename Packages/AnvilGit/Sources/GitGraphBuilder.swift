import Foundation
import AnvilDomain

/// Builds commit graph data for visualization, modeling parent-child
/// relationships between commits for rendering branch topology.
public struct GitGraphBuilder: Sendable {

    public struct GraphNode: Sendable {
        public let commit: Commit
        public let parents: [String]
        public let column: Int
        public let isHead: Bool
    }

    public struct CommitGraph: Sendable {
        public let nodes: [GraphNode]
        public let maxColumns: Int
    }

    public init() {}

    /// Build a commit graph from a list of commits (ordered newest-first).
    /// Assigns column positions based on parent relationships.
    public func buildGraph(from commits: [Commit], headRef: String?) -> CommitGraph {
        guard !commits.isEmpty else {
            return CommitGraph(nodes: [], maxColumns: 0)
        }

        var columnForHash: [String: Int] = [:]
        var activeColumns: [String?] = [] // tracks which hash owns each column
        var nodes: [GraphNode] = []

        for commit in commits {
            let column: Int
            if let existing = columnForHash[commit.id] {
                column = existing
            } else {
                // Find an empty column or create a new one
                column = nextAvailableColumn(&activeColumns)
                activeColumns[column] = commit.id
            }

            // First parent continues in the same column
            if let firstParent = commit.parents.first {
                columnForHash[firstParent] = column
                activeColumns[column] = firstParent
            } else {
                // No parents — free the column
                activeColumns[column] = nil
            }

            // Additional parents get their own columns
            for parent in commit.parents.dropFirst() {
                if columnForHash[parent] == nil {
                    let parentCol = nextAvailableColumn(&activeColumns)
                    columnForHash[parent] = parentCol
                    activeColumns[parentCol] = parent
                }
            }

            let isHead = commit.id == headRef || commit.shortHash == headRef

            nodes.append(GraphNode(
                commit: commit,
                parents: commit.parents,
                column: column,
                isHead: isHead
            ))
        }

        let maxCol = nodes.map(\.column).max().map { $0 + 1 } ?? 0
        return CommitGraph(nodes: nodes, maxColumns: maxCol)
    }

    private func nextAvailableColumn(_ columns: inout [String?]) -> Int {
        if let idx = columns.firstIndex(of: nil) {
            return idx
        }
        columns.append(nil)
        return columns.count - 1
    }
}
