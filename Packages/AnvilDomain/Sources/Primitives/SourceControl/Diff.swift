import Foundation

public struct FileDiff: Sendable, Identifiable, Codable {
    public var id: String { filePath }
    public let filePath: String
    public let oldPath: String?
    public let status: DiffFileStatus
    public let hunks: [DiffHunk]
    public let isBinary: Bool

    public init(filePath: String, oldPath: String? = nil, status: DiffFileStatus, hunks: [DiffHunk] = [], isBinary: Bool = false) {
        self.filePath = filePath
        self.oldPath = oldPath
        self.status = status
        self.hunks = hunks
        self.isBinary = isBinary
    }
}

public enum DiffFileStatus: String, Sendable, Codable {
    case added, modified, deleted, renamed, copied
}

public struct DiffHunk: Sendable, Codable, Identifiable {
    public let id: String
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let header: String
    public let lines: [DiffLine]

    public init(id: String = UUID().uuidString, oldStart: Int, oldCount: Int, newStart: Int, newCount: Int, header: String, lines: [DiffLine]) {
        self.id = id
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.header = header
        self.lines = lines
    }
}

public struct DiffLine: Sendable, Codable {
    public let type: DiffLineType
    public let content: String
    public let oldLineNumber: Int?
    public let newLineNumber: Int?

    public init(type: DiffLineType, content: String, oldLineNumber: Int? = nil, newLineNumber: Int? = nil) {
        self.type = type
        self.content = content
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
    }
}

public enum DiffLineType: String, Sendable, Codable {
    case context, added, removed
}
