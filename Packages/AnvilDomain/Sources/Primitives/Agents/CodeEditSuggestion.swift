import Foundation

/// Represents an AI-proposed code edit with per-hunk accept/reject state.
public struct CodeEditSuggestion: Sendable, Identifiable, Codable {
    public let id: String
    public let filePath: String
    public let description: String
    public var hunks: [EditHunk]

    public var allAccepted: Bool { hunks.allSatisfy { $0.state == .accepted } }
    public var allRejected: Bool { hunks.allSatisfy { $0.state == .rejected } }
    public var hasPending: Bool { hunks.contains { $0.state == .pending } }
    public var acceptedCount: Int { hunks.filter { $0.state == .accepted }.count }
    public var rejectedCount: Int { hunks.filter { $0.state == .rejected }.count }

    public init(id: String = UUID().uuidString, filePath: String, description: String = "", hunks: [EditHunk] = []) {
        self.id = id
        self.filePath = filePath
        self.description = description
        self.hunks = hunks
    }
}

public struct EditHunk: Sendable, Identifiable, Codable {
    public let id: String
    public let header: String
    public let oldStart: Int
    public let oldCount: Int
    public let newStart: Int
    public let newCount: Int
    public let removedLines: [String]
    public let addedLines: [String]
    public let contextBefore: [String]
    public let contextAfter: [String]
    public var state: EditHunkState

    public init(
        id: String = UUID().uuidString,
        header: String = "",
        oldStart: Int = 0,
        oldCount: Int = 0,
        newStart: Int = 0,
        newCount: Int = 0,
        removedLines: [String] = [],
        addedLines: [String] = [],
        contextBefore: [String] = [],
        contextAfter: [String] = [],
        state: EditHunkState = .pending
    ) {
        self.id = id
        self.header = header
        self.oldStart = oldStart
        self.oldCount = oldCount
        self.newStart = newStart
        self.newCount = newCount
        self.removedLines = removedLines
        self.addedLines = addedLines
        self.contextBefore = contextBefore
        self.contextAfter = contextAfter
        self.state = state
    }
}

public enum EditHunkState: String, Sendable, Codable {
    case pending, accepted, rejected
}
