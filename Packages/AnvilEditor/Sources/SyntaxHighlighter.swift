import Foundation

/// Token types for syntax highlighting.
public enum SyntaxTokenKind: Sendable {
    case keyword
    case type
    case string
    case number
    case comment
    case function
    case property
    case `operator`
    case preprocessor
    case attribute
    case plain
}

/// A single highlighted token within a line.
public struct SyntaxToken: Sendable {
    public let text: String
    public let kind: SyntaxTokenKind

    public init(text: String, kind: SyntaxTokenKind) {
        self.text = text
        self.kind = kind
    }
}

/// Multi-language syntax highlighter.
///
/// Tokenizes source code lines by language for display in the editor.
/// Currently uses regex-based tokenization; designed to be replaced by
/// Tree-sitter grammars in the future without changing the API.
public final class SyntaxHighlighter: Sendable {
    public let language: SyntaxLanguage

    public init(language: SyntaxLanguage) {
        self.language = language
    }

    /// Detect language from file extension.
    public static func language(forExtension ext: String) -> SyntaxLanguage {
        switch ext.lowercased() {
        case "swift":                       .swift
        case "ts", "tsx":                   .typescript
        case "js", "jsx", "mjs", "cjs":    .javascript
        case "py", "pyw":                   .python
        case "rs":                          .rust
        case "go":                          .go
        case "json":                        .json
        case "yaml", "yml":                 .yaml
        case "md", "markdown":              .markdown
        case "html", "htm":                 .html
        case "css":                         .css
        case "c", "h":                      .c
        case "cpp", "hpp", "cc", "cxx":     .cpp
        case "java":                        .java
        case "rb":                          .ruby
        case "sh", "bash", "zsh":           .shell
        case "sql":                         .sql
        case "toml":                        .toml
        case "xml":                         .xml
        default:                            .plaintext
        }
    }

    /// Tokenize a single line of source code.
    public func tokenize(_ line: String) -> [SyntaxToken] {
        if line.isEmpty { return [SyntaxToken(text: "", kind: .plain)] }

        switch language {
        case .swift:       return tokenizeSwift(line)
        case .typescript, .javascript: return tokenizeTypeScript(line)
        case .python:      return tokenizePython(line)
        case .rust:        return tokenizeRust(line)
        case .go:          return tokenizeGo(line)
        case .json:        return tokenizeJSON(line)
        case .yaml:        return tokenizeYAML(line)
        case .markdown:    return tokenizeMarkdown(line)
        case .html, .xml:  return tokenizeHTML(line)
        case .css:         return tokenizeCSS(line)
        case .c, .cpp:     return tokenizeCLike(line, keywords: cKeywords)
        case .java:        return tokenizeCLike(line, keywords: javaKeywords)
        case .ruby:        return tokenizeRuby(line)
        case .shell:       return tokenizeShell(line)
        case .sql:         return tokenizeSQL(line)
        case .toml:        return tokenizeTOML(line)
        case .plaintext:   return [SyntaxToken(text: line, kind: .plain)]
        }
    }
}

// MARK: - Language Enum

public enum SyntaxLanguage: String, Sendable, CaseIterable {
    case swift, typescript, javascript, python, rust, go
    case json, yaml, markdown, html, xml, css
    case c, cpp, java, ruby, shell, sql, toml
    case plaintext
}

// MARK: - Tokenizers

extension SyntaxHighlighter {

    // MARK: Swift

    private static let swiftKeywords: Set<String> = [
        "actor", "any", "as", "associatedtype", "async", "await", "break", "case", "catch",
        "class", "continue", "default", "defer", "deinit", "do", "else", "enum", "extension",
        "fallthrough", "false", "fileprivate", "final", "for", "func", "guard", "if", "import",
        "in", "indirect", "infix", "init", "inout", "internal", "is", "isolated", "lazy",
        "let", "mutating", "nil", "nonisolated", "nonmutating", "open", "operator", "optional",
        "override", "postfix", "precedencegroup", "prefix", "private", "protocol", "public",
        "repeat", "required", "rethrows", "return", "self", "Self", "some", "static", "struct",
        "subscript", "super", "switch", "throw", "throws", "true", "try", "typealias", "var",
        "where", "while", "yield",
    ]

    private static let swiftTypes: Set<String> = [
        "Int", "String", "Double", "Float", "Bool", "Array", "Dictionary", "Set", "Optional",
        "Result", "Error", "Void", "Any", "AnyObject", "Never", "Date", "URL", "Data",
        "CGFloat", "CGPoint", "CGRect", "CGSize", "UUID", "Codable", "Sendable", "Identifiable",
        "View", "ObservableObject", "Published", "State", "Binding", "ObservedObject",
        "EnvironmentObject", "Environment", "MainActor", "Task",
    ]

    private func tokenizeSwift(_ line: String) -> [SyntaxToken] {
        return tokenizeCLike(line, keywords: Self.swiftKeywords, types: Self.swiftTypes, attributes: true)
    }

    // MARK: TypeScript / JavaScript

    private static let tsKeywords: Set<String> = [
        "abstract", "as", "async", "await", "break", "case", "catch", "class", "const",
        "continue", "debugger", "default", "delete", "do", "else", "enum", "export",
        "extends", "false", "finally", "for", "from", "function", "get", "if", "implements",
        "import", "in", "instanceof", "interface", "let", "new", "null", "of", "package",
        "private", "protected", "public", "readonly", "return", "set", "static", "super",
        "switch", "this", "throw", "true", "try", "type", "typeof", "undefined", "var",
        "void", "while", "with", "yield",
    ]

    private func tokenizeTypeScript(_ line: String) -> [SyntaxToken] {
        return tokenizeCLike(line, keywords: Self.tsKeywords)
    }

    // MARK: Python

    private static let pythonKeywords: Set<String> = [
        "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class",
        "continue", "def", "del", "elif", "else", "except", "finally", "for", "from",
        "global", "if", "import", "in", "is", "lambda", "nonlocal", "not", "or", "pass",
        "raise", "return", "try", "while", "with", "yield",
    ]

    private func tokenizePython(_ line: String) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        if trimmed.hasPrefix("@") {
            return [SyntaxToken(text: line, kind: .attribute)]
        }
        return tokenizeGeneric(line, keywords: Self.pythonKeywords, singleLineComment: "#")
    }

    // MARK: Rust

    private static let rustKeywords: Set<String> = [
        "as", "async", "await", "break", "const", "continue", "crate", "dyn", "else",
        "enum", "extern", "false", "fn", "for", "if", "impl", "in", "let", "loop",
        "match", "mod", "move", "mut", "pub", "ref", "return", "self", "Self", "static",
        "struct", "super", "trait", "true", "type", "unsafe", "use", "where", "while",
    ]

    private func tokenizeRust(_ line: String) -> [SyntaxToken] {
        return tokenizeCLike(line, keywords: Self.rustKeywords)
    }

    // MARK: Go

    private static let goKeywords: Set<String> = [
        "break", "case", "chan", "const", "continue", "default", "defer", "else",
        "fallthrough", "for", "func", "go", "goto", "if", "import", "interface",
        "map", "package", "range", "return", "select", "struct", "switch", "type", "var",
        "true", "false", "nil", "iota",
    ]

    private func tokenizeGo(_ line: String) -> [SyntaxToken] {
        return tokenizeCLike(line, keywords: Self.goKeywords)
    }

    // MARK: C / C++

    private var cKeywords: Set<String> {
        [
            "auto", "break", "case", "char", "const", "continue", "default", "do", "double",
            "else", "enum", "extern", "float", "for", "goto", "if", "inline", "int", "long",
            "register", "restrict", "return", "short", "signed", "sizeof", "static", "struct",
            "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
            // C++ additions
            "bool", "catch", "class", "delete", "false", "friend", "namespace", "new",
            "nullptr", "operator", "private", "protected", "public", "template", "this",
            "throw", "true", "try", "typeid", "typename", "using", "virtual",
        ]
    }

    // MARK: Java

    private var javaKeywords: Set<String> {
        [
            "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
            "class", "continue", "default", "do", "double", "else", "enum", "extends",
            "false", "final", "finally", "float", "for", "if", "implements", "import",
            "instanceof", "int", "interface", "long", "native", "new", "null", "package",
            "private", "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws", "transient",
            "true", "try", "void", "volatile", "while",
        ]
    }

    // MARK: Ruby

    private func tokenizeRuby(_ line: String) -> [SyntaxToken] {
        let rubyKeywords: Set<String> = [
            "BEGIN", "END", "alias", "and", "begin", "break", "case", "class", "def",
            "defined?", "do", "else", "elsif", "end", "ensure", "false", "for", "if",
            "in", "module", "next", "nil", "not", "or", "redo", "rescue", "retry",
            "return", "self", "super", "then", "true", "undef", "unless", "until",
            "when", "while", "yield",
        ]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        return tokenizeGeneric(line, keywords: rubyKeywords, singleLineComment: "#")
    }

    // MARK: Shell

    private func tokenizeShell(_ line: String) -> [SyntaxToken] {
        let shellKeywords: Set<String> = [
            "if", "then", "else", "elif", "fi", "case", "esac", "for", "while", "until",
            "do", "done", "in", "function", "select", "time", "coproc", "export",
            "readonly", "local", "declare", "typeset", "unset", "return", "exit",
            "source", "eval", "exec", "set",
        ]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        return tokenizeGeneric(line, keywords: shellKeywords, singleLineComment: "#")
    }

    // MARK: SQL

    private func tokenizeSQL(_ line: String) -> [SyntaxToken] {
        let sqlKeywords: Set<String> = [
            "SELECT", "FROM", "WHERE", "INSERT", "INTO", "VALUES", "UPDATE", "SET",
            "DELETE", "CREATE", "TABLE", "ALTER", "DROP", "INDEX", "VIEW", "JOIN",
            "LEFT", "RIGHT", "INNER", "OUTER", "ON", "AND", "OR", "NOT", "NULL",
            "IS", "IN", "BETWEEN", "LIKE", "ORDER", "BY", "GROUP", "HAVING", "LIMIT",
            "OFFSET", "UNION", "ALL", "AS", "DISTINCT", "EXISTS", "CASE", "WHEN",
            "THEN", "ELSE", "END", "BEGIN", "COMMIT", "ROLLBACK", "PRIMARY", "KEY",
            "FOREIGN", "REFERENCES", "CONSTRAINT", "DEFAULT", "CHECK", "UNIQUE",
            // Also match lowercase
            "select", "from", "where", "insert", "into", "values", "update", "set",
            "delete", "create", "table", "alter", "drop", "index", "view", "join",
            "left", "right", "inner", "outer", "on", "and", "or", "not", "null",
            "is", "in", "between", "like", "order", "by", "group", "having", "limit",
            "offset", "union", "all", "as", "distinct", "exists", "case", "when",
            "then", "else", "end", "begin", "commit", "rollback", "primary", "key",
            "foreign", "references", "constraint", "default", "check", "unique",
        ]
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("--") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        return tokenizeGeneric(line, keywords: sqlKeywords, singleLineComment: "--")
    }

    // MARK: JSON

    private func tokenizeJSON(_ line: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var current = line.startIndex

        while current < line.endIndex {
            let char = line[current]

            if char == "\"" {
                let result = consumeString(line, from: current)
                // Check if it's a key (followed by colon)
                let afterString = result.end
                let restTrimmed = line[afterString...].trimmingCharacters(in: .whitespaces)
                let kind: SyntaxTokenKind = restTrimmed.hasPrefix(":") ? .property : .string
                tokens.append(SyntaxToken(text: result.text, kind: kind))
                current = result.end
            } else if char.isNumber || char == "-" {
                let result = consumeNumber(line, from: current)
                tokens.append(SyntaxToken(text: result.text, kind: .number))
                current = result.end
            } else if line[current...].hasPrefix("true") || line[current...].hasPrefix("false") || line[current...].hasPrefix("null") {
                let word = line[current...].hasPrefix("true") ? "true" : line[current...].hasPrefix("false") ? "false" : "null"
                tokens.append(SyntaxToken(text: word, kind: .keyword))
                current = line.index(current, offsetBy: word.count)
            } else {
                tokens.append(SyntaxToken(text: String(char), kind: .plain))
                current = line.index(after: current)
            }
        }
        return tokens
    }

    // MARK: YAML

    private func tokenizeYAML(_ line: String) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        if trimmed.hasPrefix("---") || trimmed.hasPrefix("...") {
            return [SyntaxToken(text: line, kind: .operator)]
        }

        // Key: value pattern
        if let colonRange = line.range(of: ":") {
            let key = String(line[line.startIndex..<colonRange.lowerBound])
            let rest = String(line[colonRange.lowerBound...])
            return [
                SyntaxToken(text: key, kind: .property),
                SyntaxToken(text: rest, kind: .string),
            ]
        }
        return [SyntaxToken(text: line, kind: .plain)]
    }

    // MARK: TOML

    private func tokenizeTOML(_ line: String) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        if trimmed.hasPrefix("[") {
            return [SyntaxToken(text: line, kind: .type)]
        }
        if let eqRange = line.range(of: "=") {
            let key = String(line[line.startIndex..<eqRange.lowerBound])
            let rest = String(line[eqRange.lowerBound...])
            return [
                SyntaxToken(text: key, kind: .property),
                SyntaxToken(text: rest, kind: .string),
            ]
        }
        return [SyntaxToken(text: line, kind: .plain)]
    }

    // MARK: Markdown

    private func tokenizeMarkdown(_ line: String) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("#") {
            return [SyntaxToken(text: line, kind: .keyword)]
        }
        if trimmed.hasPrefix("```") {
            return [SyntaxToken(text: line, kind: .preprocessor)]
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            return [
                SyntaxToken(text: String(trimmed.prefix(2)), kind: .operator),
                SyntaxToken(text: String(trimmed.dropFirst(2)), kind: .plain),
            ]
        }
        return [SyntaxToken(text: line, kind: .plain)]
    }

    // MARK: HTML / XML

    private func tokenizeHTML(_ line: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var current = line.startIndex

        while current < line.endIndex {
            let char = line[current]

            if char == "<" {
                // Consume a tag, splitting out quoted attribute values as strings so
                // `<a href="x">` highlights the value separately from the tag syntax.
                var end = line.index(after: current)
                var run = current
                while end < line.endIndex && line[end] != ">" {
                    if line[end] == "\"" {
                        if run < end {
                            tokens.append(SyntaxToken(text: String(line[run..<end]), kind: .keyword))
                        }
                        let result = consumeString(line, from: end)
                        tokens.append(SyntaxToken(text: result.text, kind: .string))
                        end = result.end
                        run = end
                    } else {
                        end = line.index(after: end)
                    }
                }
                if end < line.endIndex {
                    end = line.index(after: end)
                }
                if run < end {
                    tokens.append(SyntaxToken(text: String(line[run..<end]), kind: .keyword))
                }
                current = end
            } else if char == "\"" {
                let result = consumeString(line, from: current)
                tokens.append(SyntaxToken(text: result.text, kind: .string))
                current = result.end
            } else {
                tokens.append(SyntaxToken(text: String(char), kind: .plain))
                current = line.index(after: current)
            }
        }
        return tokens
    }

    // MARK: CSS

    private func tokenizeCSS(_ line: String) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("/*") || trimmed.hasPrefix("*") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        if let colonRange = line.range(of: ":") {
            let prop = String(line[line.startIndex..<colonRange.lowerBound])
            let value = String(line[colonRange.lowerBound...])
            return [
                SyntaxToken(text: prop, kind: .property),
                SyntaxToken(text: value, kind: .string),
            ]
        }
        return [SyntaxToken(text: line, kind: .type)]
    }

    // MARK: - Generic C-like Tokenizer

    private func tokenizeCLike(_ line: String, keywords: Set<String>, types: Set<String>? = nil, attributes: Bool = false) -> [SyntaxToken] {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Full-line comment
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("///") {
            return [SyntaxToken(text: line, kind: .comment)]
        }
        // Preprocessor
        if trimmed.hasPrefix("#") && !attributes {
            return [SyntaxToken(text: line, kind: .preprocessor)]
        }
        // Attribute (Swift @)
        if attributes && trimmed.hasPrefix("@") {
            return [SyntaxToken(text: line, kind: .attribute)]
        }

        return tokenizeGeneric(line, keywords: keywords, types: types, singleLineComment: "//")
    }

    private func tokenizeGeneric(_ line: String, keywords: Set<String>, types: Set<String>? = nil, singleLineComment: String = "//") -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var current = line.startIndex

        while current < line.endIndex {
            let char = line[current]

            // Check for single-line comment
            let remaining = line[current...]
            if remaining.hasPrefix(singleLineComment) {
                tokens.append(SyntaxToken(text: String(remaining), kind: .comment))
                return tokens
            }

            // String
            if char == "\"" || char == "'" || char == "`" {
                let result = consumeQuoted(line, from: current, quote: char)
                tokens.append(SyntaxToken(text: result.text, kind: .string))
                current = result.end
            }
            // Number
            else if char.isNumber && (current == line.startIndex || !line[line.index(before: current)].isLetter) {
                let result = consumeNumber(line, from: current)
                tokens.append(SyntaxToken(text: result.text, kind: .number))
                current = result.end
            }
            // Word
            else if char.isLetter || char == "_" || char == "@" {
                let result = consumeWord(line, from: current)
                let kind: SyntaxTokenKind
                if keywords.contains(result.text) {
                    kind = .keyword
                } else if types?.contains(result.text) == true {
                    kind = .type
                } else if result.end < line.endIndex && line[result.end] == "(" {
                    kind = .function
                } else if result.text.first?.isUppercase == true {
                    kind = .type
                } else {
                    kind = .plain
                }
                tokens.append(SyntaxToken(text: result.text, kind: kind))
                current = result.end
            }
            // Operators
            else if "+-*/%=<>!&|^~?".contains(char) {
                tokens.append(SyntaxToken(text: String(char), kind: .operator))
                current = line.index(after: current)
            }
            // Other
            else {
                tokens.append(SyntaxToken(text: String(char), kind: .plain))
                current = line.index(after: current)
            }
        }

        return tokens
    }

    // MARK: - Helpers

    private func consumeString(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        return consumeQuoted(line, from: start, quote: "\"")
    }

    private func consumeQuoted(_ line: String, from start: String.Index, quote: Character) -> (text: String, end: String.Index) {
        var pos = line.index(after: start)
        while pos < line.endIndex {
            if line[pos] == "\\" && line.index(after: pos) < line.endIndex {
                pos = line.index(pos, offsetBy: 2)
                continue
            }
            if line[pos] == quote {
                pos = line.index(after: pos)
                return (String(line[start..<pos]), pos)
            }
            pos = line.index(after: pos)
        }
        return (String(line[start..<line.endIndex]), line.endIndex)
    }

    private func consumeNumber(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        var pos = start
        while pos < line.endIndex && (line[pos].isNumber || line[pos] == "." || line[pos] == "x" || line[pos] == "X" || line[pos] == "_") {
            pos = line.index(after: pos)
        }
        return (String(line[start..<pos]), pos)
    }

    private func consumeWord(_ line: String, from start: String.Index) -> (text: String, end: String.Index) {
        var pos = start
        while pos < line.endIndex && (line[pos].isLetter || line[pos].isNumber || line[pos] == "_" || line[pos] == "@" || line[pos] == "?") {
            pos = line.index(after: pos)
        }
        return (String(line[start..<pos]), pos)
    }
}
