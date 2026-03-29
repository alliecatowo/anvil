import Foundation

public struct MergeConflict: Sendable, Identifiable, Codable {
    public var id: String { filePath }
    public let filePath: String
    public let oursContent: String
    public let theirsContent: String
    public let baseContent: String?
    public var isResolved: Bool

    public init(filePath: String, oursContent: String, theirsContent: String, baseContent: String? = nil, isResolved: Bool = false) {
        self.filePath = filePath
        self.oursContent = oursContent
        self.theirsContent = theirsContent
        self.baseContent = baseContent
        self.isResolved = isResolved
    }
}

public enum MergeStrategy: String, Sendable, Codable {
    case merge, squash, rebase, fastForward
}

public enum MergeResult: Sendable {
    case success(commit: Commit)
    case conflicts([MergeConflict])
    case alreadyUpToDate
}

public struct BlameLine: Sendable, Codable {
    public let lineNumber: Int
    public let commitHash: String
    public let author: String
    public let date: Date
    public let content: String

    public init(lineNumber: Int, commitHash: String, author: String, date: Date, content: String) {
        self.lineNumber = lineNumber
        self.commitHash = commitHash
        self.author = author
        self.date = date
        self.content = content
    }
}

public struct Stash: Sendable, Identifiable, Codable {
    public let id: String
    public let index: Int
    public let message: String
    public let date: Date

    public init(id: String = UUID().uuidString, index: Int, message: String, date: Date) {
        self.id = id
        self.index = index
        self.message = message
        self.date = date
    }
}

public struct Worktree: Sendable, Identifiable, Codable {
    public var id: String { path }
    public let path: String
    public let branch: String?
    public let headSHA: String?
    public let isClean: Bool
    public let isMain: Bool

    public init(path: String, branch: String? = nil, headSHA: String? = nil, isClean: Bool = true, isMain: Bool = false) {
        self.path = path
        self.branch = branch
        self.headSHA = headSHA
        self.isClean = isClean
        self.isMain = isMain
    }
}

public struct Tag: Sendable, Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let targetCommit: String
    public let annotation: String?
    public let date: Date?

    public init(name: String, targetCommit: String, annotation: String? = nil, date: Date? = nil) {
        self.name = name
        self.targetCommit = targetCommit
        self.annotation = annotation
        self.date = date
    }
}
