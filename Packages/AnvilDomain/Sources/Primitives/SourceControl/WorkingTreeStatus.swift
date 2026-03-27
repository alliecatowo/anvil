import Foundation

/// Represents a single file's status in the git working tree.
public struct GitFileChange: Sendable, Identifiable, Codable, Hashable {
    public var id: String { filePath }
    public let filePath: String
    public let status: GitFileChangeStatus
    public let staged: Bool

    public init(filePath: String, status: GitFileChangeStatus, staged: Bool) {
        self.filePath = filePath
        self.status = status
        self.staged = staged
    }

    /// Short filename (last path component).
    public var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    /// Parent directory path.
    public var directory: String {
        let dir = (filePath as NSString).deletingLastPathComponent
        return dir.isEmpty ? "" : dir
    }
}

public enum GitFileChangeStatus: String, Sendable, Codable, Hashable {
    case modified = "M"
    case added = "A"
    case deleted = "D"
    case renamed = "R"
    case copied = "C"
    case untracked = "?"
    case unmerged = "U"
}
