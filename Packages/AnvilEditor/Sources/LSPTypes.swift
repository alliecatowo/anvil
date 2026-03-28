import Foundation

// MARK: - LSP Value Types

/// A diagnostic message from the language server (error, warning, etc.).
public struct LSPDiagnostic: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let uri: String
    public let line: Int          // 0-based
    public let character: Int     // 0-based
    public let endLine: Int
    public let endCharacter: Int
    public let severity: DiagnosticSeverity
    public let message: String
    public let source: String?

    public init(
        id: UUID = UUID(),
        uri: String,
        line: Int,
        character: Int,
        endLine: Int,
        endCharacter: Int,
        severity: DiagnosticSeverity,
        message: String,
        source: String? = nil
    ) {
        self.id = id
        self.uri = uri
        self.line = line
        self.character = character
        self.endLine = endLine
        self.endCharacter = endCharacter
        self.severity = severity
        self.message = message
        self.source = source
    }

    public enum DiagnosticSeverity: Int, Sendable {
        case error = 1
        case warning = 2
        case information = 3
        case hint = 4
    }
}

/// A completion item returned by the language server.
public struct CompletionItem: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let label: String
    public let kind: CompletionKind
    public let detail: String?
    public let insertText: String?

    public init(
        id: UUID = UUID(),
        label: String,
        kind: CompletionKind = .text,
        detail: String? = nil,
        insertText: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.detail = detail
        self.insertText = insertText
    }

    public enum CompletionKind: Int, Sendable {
        case text = 1
        case method = 2
        case function = 3
        case constructor = 4
        case field = 5
        case variable = 6
        case classKind = 7
        case interface = 8
        case module = 9
        case property = 10
        case unit = 11
        case value = 12
        case enumKind = 13
        case keyword = 14
        case snippet = 15
        case color = 16
        case file = 17
        case reference = 18
        case folder = 19
        case enumMember = 20
        case constant = 21
        case structKind = 22
        case event = 23
        case operatorKind = 24
        case typeParameter = 25
    }
}

/// A source location returned by go-to-definition.
public struct LSPLocation: Sendable, Equatable {
    public let uri: String
    public let line: Int       // 0-based
    public let character: Int  // 0-based

    public init(uri: String, line: Int, character: Int) {
        self.uri = uri
        self.line = line
        self.character = character
    }
}
