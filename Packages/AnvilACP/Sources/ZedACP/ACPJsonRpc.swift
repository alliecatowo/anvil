import Foundation

// MARK: - JSON-RPC 2.0 Message Types for Zed ACP

/// Represents the id field of a JSON-RPC message, which can be an integer or string.
public enum ACPMessageId: Sendable, Hashable {
    case int(Int)
    case string(String)
}

extension ACPMessageId: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .int(intVal)
        } else if let strVal = try? container.decode(String.self) {
            self = .string(strVal)
        } else {
            throw DecodingError.typeMismatch(
                ACPMessageId.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected Int or String for JSON-RPC id")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        }
    }
}

/// A JSON-RPC 2.0 error object.
public struct ACPJsonRpcError: Codable, Sendable {
    public let code: Int
    public let message: String
    public let data: ACPAnyCodable?

    public init(code: Int, message: String, data: ACPAnyCodable? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    public static let methodNotFound = ACPJsonRpcError(code: -32601, message: "Method not found")
    public static let internalError = ACPJsonRpcError(code: -32603, message: "Internal error")
}

/// A complete JSON-RPC 2.0 message used for Zed ACP communication.
///
/// Discriminated as:
/// - **Request**: has `id` and `method`
/// - **Response**: has `id`, no `method`
/// - **Notification**: has `method`, no `id`
public struct ACPJsonRpcMessage: Codable, Sendable {
    public let jsonrpc: String
    public let id: ACPMessageId?
    public let method: String?
    public let params: ACPAnyCodable?
    public let result: ACPAnyCodable?
    public let error: ACPJsonRpcError?

    public init(
        id: ACPMessageId? = nil,
        method: String? = nil,
        params: ACPAnyCodable? = nil,
        result: ACPAnyCodable? = nil,
        error: ACPJsonRpcError? = nil
    ) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    /// Create a request message.
    public static func request(id: ACPMessageId, method: String, params: ACPAnyCodable? = nil) -> ACPJsonRpcMessage {
        ACPJsonRpcMessage(id: id, method: method, params: params)
    }

    /// Create a notification (no id).
    public static func notification(method: String, params: ACPAnyCodable? = nil) -> ACPJsonRpcMessage {
        ACPJsonRpcMessage(method: method, params: params)
    }

    /// Create a success response.
    public static func response(id: ACPMessageId, result: ACPAnyCodable) -> ACPJsonRpcMessage {
        ACPJsonRpcMessage(id: id, result: result)
    }

    /// Create an error response.
    public static func errorResponse(id: ACPMessageId, error: ACPJsonRpcError) -> ACPJsonRpcMessage {
        ACPJsonRpcMessage(id: id, error: error)
    }

    /// Whether this is an inbound request (has id + method).
    public var isRequest: Bool { id != nil && method != nil }

    /// Whether this is a response to one of our requests (has id, no method).
    public var isResponse: Bool { id != nil && method == nil }

    /// Whether this is a notification (has method, no id).
    public var isNotification: Bool { method != nil && id == nil }
}
