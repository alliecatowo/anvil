import Testing
@testable import AnvilEditor

@Test func diagnosticCreation() {
    let diag = LSPDiagnostic(
        uri: "file:///test.swift",
        line: 0,
        character: 5,
        endLine: 0,
        endCharacter: 10,
        severity: .error,
        message: "Use of undeclared type",
        source: "sourcekit"
    )
    #expect(diag.severity == .error)
    #expect(diag.line == 0)
    #expect(diag.message == "Use of undeclared type")
}

@Test func completionItemCreation() {
    let item = CompletionItem(
        label: "viewDidLoad",
        kind: .method,
        detail: "() -> Void"
    )
    #expect(item.label == "viewDidLoad")
    #expect(item.kind == .method)
}

@Test func locationCreation() {
    let loc = LSPLocation(uri: "file:///test.swift", line: 10, character: 4)
    #expect(loc.uri == "file:///test.swift")
    #expect(loc.line == 10)
}
