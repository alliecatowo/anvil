import XCTest
@testable import AnvilEditor

/// XCTest coverage for SyntaxHighlighter:
/// - Language detection from file extensions
/// - Swift keyword/type/string/comment/attribute tokenization
/// - TypeScript, Python, Rust, Go keyword coverage
/// - JSON, YAML, TOML, Markdown, HTML, CSS, SQL, Shell
/// - Plaintext passthrough
/// - Edge cases: empty line, numbers, operators
final class SyntaxHighlighterTests: XCTestCase {

    // MARK: - Language Detection

    func testSwiftExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "swift"), .swift)
    }

    func testTypeScriptExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "ts"), .typescript)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "tsx"), .typescript)
    }

    func testJavaScriptExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "js"), .javascript)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "jsx"), .javascript)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "mjs"), .javascript)
    }

    func testPythonExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "py"), .python)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "pyw"), .python)
    }

    func testRustExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "rs"), .rust)
    }

    func testGoExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "go"), .go)
    }

    func testJSONExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "json"), .json)
    }

    func testYAMLExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "yaml"), .yaml)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "yml"), .yaml)
    }

    func testMarkdownExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "md"), .markdown)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "markdown"), .markdown)
    }

    func testHTMLExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "html"), .html)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "htm"), .html)
    }

    func testCSSExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "css"), .css)
    }

    func testCExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "c"), .c)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "h"), .c)
    }

    func testCppExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "cpp"), .cpp)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "hpp"), .cpp)
    }

    func testJavaExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "java"), .java)
    }

    func testRubyExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "rb"), .ruby)
    }

    func testShellExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "sh"), .shell)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "bash"), .shell)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "zsh"), .shell)
    }

    func testSQLExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "sql"), .sql)
    }

    func testTOMLExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "toml"), .toml)
    }

    func testXMLExtension() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "xml"), .xml)
    }

    func testUnknownExtensionIsPlaintext() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "xyz"), .plaintext)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: ""), .plaintext)
    }

    func testExtensionDetectionIsCaseInsensitive() {
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "SWIFT"), .swift)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "Swift"), .swift)
        XCTAssertEqual(SyntaxHighlighter.language(forExtension: "PY"), .python)
    }

    // MARK: - Swift Tokenization

    private var swift: SyntaxHighlighter { SyntaxHighlighter(language: .swift) }

    func testSwiftKeywordIsTokenized() {
        let tokens = swift.tokenize("func greet() {")
        let kinds = tokens.map(\.kind)
        XCTAssertTrue(kinds.contains(.keyword), "Expected 'func' to be tokenized as keyword")
        let kw = tokens.first { $0.kind == .keyword }
        XCTAssertEqual(kw?.text, "func")
    }

    func testSwiftLetKeyword() {
        let tokens = swift.tokenize("let x = 42")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "let" })
    }

    func testSwiftVarKeyword() {
        let tokens = swift.tokenize("var count = 0")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "var" })
    }

    func testSwiftStructKeyword() {
        let tokens = swift.tokenize("struct MyModel {")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "struct" })
    }

    func testSwiftClassKeyword() {
        let tokens = swift.tokenize("class MyClass: NSObject {")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "class" })
    }

    func testSwiftReturnKeyword() {
        let tokens = swift.tokenize("    return result")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "return" })
    }

    func testSwiftStringLiteralTokenized() {
        let tokens = swift.tokenize(#"let s = "hello world""#)
        XCTAssertTrue(tokens.contains { $0.kind == .string && $0.text.contains("hello") })
    }

    func testSwiftSingleLineCommentTokenized() {
        let tokens = swift.tokenize("// This is a comment")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testSwiftDocCommentTokenized() {
        let tokens = swift.tokenize("/// Documentation comment")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testSwiftInlineCommentTokenized() {
        let tokens = swift.tokenize("let x = 1 // inline")
        XCTAssertTrue(tokens.contains { $0.kind == .comment && $0.text.contains("inline") })
    }

    func testSwiftAttributeTokenized() {
        let tokens = swift.tokenize("@MainActor")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .attribute)
    }

    func testSwiftBuiltinTypeTokenized() {
        let tokens = swift.tokenize("var name: String = \"\"")
        XCTAssertTrue(tokens.contains { $0.kind == .type && $0.text == "String" })
    }

    func testSwiftNumberTokenized() {
        let tokens = swift.tokenize("let n = 42")
        XCTAssertTrue(tokens.contains { $0.kind == .number && $0.text == "42" })
    }

    func testSwiftFunctionCallTokenized() {
        let tokens = swift.tokenize("greet()")
        XCTAssertTrue(tokens.contains { $0.kind == .function && $0.text == "greet" })
    }

    func testSwiftEmptyLine() {
        let tokens = swift.tokenize("")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .plain)
        XCTAssertEqual(tokens[0].text, "")
    }

    func testSwiftPreprocessorNotTreatedAsPreprocessor() {
        // Swift doesn't use # as preprocessor (except #if, which still goes through generic)
        // Attributes starting with @ are .attribute, # lines without @ go through generic
        let tokens = swift.tokenize("#if DEBUG")
        XCTAssertFalse(tokens.isEmpty)
    }

    // MARK: - TypeScript Tokenization

    private var ts: SyntaxHighlighter { SyntaxHighlighter(language: .typescript) }

    func testTypeScriptFunctionKeyword() {
        let tokens = ts.tokenize("function hello() {")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "function" })
    }

    func testTypeScriptConstKeyword() {
        let tokens = ts.tokenize("const x = 1")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "const" })
    }

    func testTypeScriptCommentTokenized() {
        let tokens = ts.tokenize("// ts comment")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    // MARK: - Python Tokenization

    private var python: SyntaxHighlighter { SyntaxHighlighter(language: .python) }

    func testPythonDefKeyword() {
        let tokens = python.tokenize("def greet():")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "def" })
    }

    func testPythonCommentLine() {
        let tokens = python.tokenize("# python comment")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testPythonDecorator() {
        let tokens = python.tokenize("@staticmethod")
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .attribute)
    }

    // MARK: - Rust Tokenization

    private var rust: SyntaxHighlighter { SyntaxHighlighter(language: .rust) }

    func testRustFnKeyword() {
        let tokens = rust.tokenize("fn main() {")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "fn" })
    }

    func testRustLetMut() {
        let tokens = rust.tokenize("let mut x = 5;")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "let" })
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "mut" })
    }

    // MARK: - Go Tokenization

    private var go: SyntaxHighlighter { SyntaxHighlighter(language: .go) }

    func testGoFuncKeyword() {
        let tokens = go.tokenize("func main() {")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "func" })
    }

    func testGoPackageKeyword() {
        let tokens = go.tokenize("package main")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "package" })
    }

    // MARK: - JSON Tokenization

    private var json: SyntaxHighlighter { SyntaxHighlighter(language: .json) }

    func testJSONStringKey() {
        let tokens = json.tokenize(#"  "name": "Alice""#)
        // First string should be a property (key), second a string (value)
        let props = tokens.filter { $0.kind == .property }
        let strs = tokens.filter { $0.kind == .string }
        XCTAssertFalse(props.isEmpty, "Expected JSON key to be .property")
        XCTAssertFalse(strs.isEmpty, "Expected JSON value to be .string")
    }

    func testJSONNumberTokenized() {
        let tokens = json.tokenize("  42")
        XCTAssertTrue(tokens.contains { $0.kind == .number })
    }

    func testJSONBooleanKeyword() {
        let tokens = json.tokenize("  true")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "true" })
    }

    // MARK: - YAML Tokenization

    private var yaml: SyntaxHighlighter { SyntaxHighlighter(language: .yaml) }

    func testYAMLCommentLine() {
        let tokens = yaml.tokenize("# yaml comment")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testYAMLKeyValuePair() {
        let tokens = yaml.tokenize("name: Alice")
        XCTAssertTrue(tokens.contains { $0.kind == .property })
        XCTAssertTrue(tokens.contains { $0.kind == .string })
    }

    func testYAMLDocumentSeparator() {
        let tokens = yaml.tokenize("---")
        XCTAssertEqual(tokens[0].kind, .operator)
    }

    // MARK: - TOML Tokenization

    private var toml: SyntaxHighlighter { SyntaxHighlighter(language: .toml) }

    func testTOMLSection() {
        let tokens = toml.tokenize("[package]")
        XCTAssertEqual(tokens[0].kind, .type)
    }

    func testTOMLKeyValue() {
        let tokens = toml.tokenize("name = \"anvil\"")
        XCTAssertTrue(tokens.contains { $0.kind == .property })
    }

    func testTOMLComment() {
        let tokens = toml.tokenize("# toml comment")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    // MARK: - Markdown Tokenization

    private var md: SyntaxHighlighter { SyntaxHighlighter(language: .markdown) }

    func testMarkdownH1() {
        let tokens = md.tokenize("# Title")
        XCTAssertEqual(tokens[0].kind, .keyword)
    }

    func testMarkdownCodeFence() {
        let tokens = md.tokenize("```swift")
        XCTAssertEqual(tokens[0].kind, .preprocessor)
    }

    func testMarkdownBulletList() {
        let tokens = md.tokenize("- item one")
        XCTAssertTrue(tokens.contains { $0.kind == .operator })
    }

    func testMarkdownPlainText() {
        let tokens = md.tokenize("Just a sentence.")
        XCTAssertEqual(tokens[0].kind, .plain)
    }

    // MARK: - HTML Tokenization

    private var html: SyntaxHighlighter { SyntaxHighlighter(language: .html) }

    func testHTMLTagTokenized() {
        let tokens = html.tokenize("<div>")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text.contains("div") })
    }

    func testHTMLStringAttribute() {
        let tokens = html.tokenize(#"<a href="https://example.com">"#)
        XCTAssertTrue(tokens.contains { $0.kind == .string })
    }

    // MARK: - CSS Tokenization

    private var css: SyntaxHighlighter { SyntaxHighlighter(language: .css) }

    func testCSSPropertyValue() {
        let tokens = css.tokenize("color: red;")
        XCTAssertTrue(tokens.contains { $0.kind == .property })
        XCTAssertTrue(tokens.contains { $0.kind == .string })
    }

    func testCSSComment() {
        let tokens = css.tokenize("/* comment */")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    func testCSSSelector() {
        let tokens = css.tokenize(".button {")
        XCTAssertEqual(tokens[0].kind, .type)
    }

    // MARK: - SQL Tokenization

    private var sql: SyntaxHighlighter { SyntaxHighlighter(language: .sql) }

    func testSQLSelectKeyword() {
        let tokens = sql.tokenize("SELECT * FROM users")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "SELECT" })
    }

    func testSQLComment() {
        let tokens = sql.tokenize("-- sql comment")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    // MARK: - Shell Tokenization

    private var shell: SyntaxHighlighter { SyntaxHighlighter(language: .shell) }

    func testShellIfKeyword() {
        let tokens = shell.tokenize("if [ -f file ]; then")
        XCTAssertTrue(tokens.contains { $0.kind == .keyword && $0.text == "if" })
    }

    func testShellComment() {
        let tokens = shell.tokenize("# shell comment")
        XCTAssertEqual(tokens[0].kind, .comment)
    }

    // MARK: - Plaintext

    func testPlaintextPassthrough() {
        let hl = SyntaxHighlighter(language: .plaintext)
        let line = "anything goes here $$##"
        let tokens = hl.tokenize(line)
        XCTAssertEqual(tokens.count, 1)
        XCTAssertEqual(tokens[0].kind, .plain)
        XCTAssertEqual(tokens[0].text, line)
    }

    func testPlaintextEmptyLine() {
        let hl = SyntaxHighlighter(language: .plaintext)
        let tokens = hl.tokenize("")
        XCTAssertEqual(tokens[0].kind, .plain)
    }

    // MARK: - SyntaxToken struct

    func testSyntaxTokenStoresTextAndKind() {
        let token = SyntaxToken(text: "func", kind: .keyword)
        XCTAssertEqual(token.text, "func")
        XCTAssertEqual(token.kind, .keyword)
    }

    // MARK: - SyntaxLanguage raw values

    func testAllLanguageCasesExist() {
        let languages = SyntaxLanguage.allCases
        XCTAssertTrue(languages.contains(.swift))
        XCTAssertTrue(languages.contains(.python))
        XCTAssertTrue(languages.contains(.plaintext))
        XCTAssertFalse(languages.isEmpty)
    }
}
