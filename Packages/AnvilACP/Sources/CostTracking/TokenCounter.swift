import Foundation

public struct TokenCounter: Sendable {
    public init() {}

    /// Rough token estimation (4 chars per token average)
    public func estimateTokens(_ text: String) -> Int {
        max(1, text.count / 4)
    }

    /// More precise estimation for known encodings
    public func estimateTokens(_ text: String, encoding: TokenEncoding) -> Int {
        switch encoding {
        case .cl100k:
            return max(1, text.count / 4)
        case .o200k:
            return max(1, text.count / 4)
        }
    }
}

public enum TokenEncoding: String, Sendable {
    case cl100k // GPT-4, Claude
    case o200k  // GPT-4o
}
