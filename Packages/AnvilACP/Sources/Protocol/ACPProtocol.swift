import Foundation

// MARK: - ACP Protocol Messages (JSON-RPC 2.0)

/// A JSON-RPC 2.0 message used for ACP communication between Anvil and provider processes.
///
/// ACP (Agent Communication Protocol) is modeled after LSP: a structured protocol for
/// communicating with AI provider processes over stdin/stdout or Unix sockets.
public struct ACPProtocolMessage: Codable, Sendable {
    public let jsonrpc: String  // "2.0"
    public let id: String?
    public let method: String?
    public let params: ACPAnyCodable?
    public let result: ACPAnyCodable?
    public let error: ACPProtocolError?

    public init(
        id: String? = nil,
        method: String? = nil,
        params: ACPAnyCodable? = nil,
        result: ACPAnyCodable? = nil,
        error: ACPProtocolError? = nil
    ) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
        self.result = result
        self.error = error
    }

    /// Convenience: create a request message
    public static func request(id: String, method: ACPMethod, params: ACPAnyCodable? = nil) -> ACPProtocolMessage {
        ACPProtocolMessage(id: id, method: method.rawValue, params: params)
    }

    /// Convenience: create a notification (no id, no response expected)
    public static func notification(method: ACPMethod, params: ACPAnyCodable? = nil) -> ACPProtocolMessage {
        ACPProtocolMessage(method: method.rawValue, params: params)
    }

    /// Convenience: create a success response
    public static func response(id: String, result: ACPAnyCodable) -> ACPProtocolMessage {
        ACPProtocolMessage(id: id, result: result)
    }

    /// Convenience: create an error response
    public static func errorResponse(id: String, error: ACPProtocolError) -> ACPProtocolMessage {
        ACPProtocolMessage(id: id, error: error)
    }
}

public struct ACPProtocolError: Codable, Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    // Standard JSON-RPC error codes
    public static let parseError = ACPProtocolError(code: -32700, message: "Parse error")
    public static let invalidRequest = ACPProtocolError(code: -32600, message: "Invalid request")
    public static let methodNotFound = ACPProtocolError(code: -32601, message: "Method not found")
    public static let invalidParams = ACPProtocolError(code: -32602, message: "Invalid params")
    public static let internalError = ACPProtocolError(code: -32603, message: "Internal error")

    // ACP-specific error codes (starting at -33000)
    public static let providerNotReady = ACPProtocolError(code: -33000, message: "Provider not ready")
    public static let sessionNotFound = ACPProtocolError(code: -33001, message: "Session not found")
    public static let modelNotAvailable = ACPProtocolError(code: -33002, message: "Model not available")
}

// MARK: - Request Methods

/// All ACP protocol methods, organized by category.
public enum ACPMethod: String, Sendable {
    // Lifecycle
    case initialize = "acp/initialize"
    case shutdown = "acp/shutdown"

    // Models
    case listModels = "acp/listModels"

    // Completions
    case complete = "acp/complete"

    // Sessions
    case sessionCreate = "acp/session/create"
    case sessionMessage = "acp/session/message"
    case sessionPause = "acp/session/pause"
    case sessionResume = "acp/session/resume"
    case sessionCancel = "acp/session/cancel"

    // Tools
    case toolsRegister = "acp/tools/register"
    case toolCallResult = "acp/tools/result"

    // Notifications (no response expected)
    case streamDelta = "acp/stream/delta"
    case streamToolCall = "acp/stream/toolCall"
    case streamComplete = "acp/stream/complete"
    case streamError = "acp/stream/error"
    case usage = "acp/usage"
}

// MARK: - Initialize

public struct ACPInitializeParams: Codable, Sendable {
    public let clientName: String
    public let clientVersion: String
    public let capabilities: ACPClientCapabilities

    public init(clientName: String = "Anvil", clientVersion: String = "0.1.0", capabilities: ACPClientCapabilities = .init()) {
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.capabilities = capabilities
    }
}

public struct ACPClientCapabilities: Codable, Sendable {
    public let streaming: Bool
    public let toolUse: Bool
    public let sessions: Bool

    public init(streaming: Bool = true, toolUse: Bool = true, sessions: Bool = true) {
        self.streaming = streaming
        self.toolUse = toolUse
        self.sessions = sessions
    }
}

public struct ACPInitializeResult: Codable, Sendable {
    public let providerName: String
    public let providerVersion: String
    public let models: [ACPModelInfo]
    public let capabilities: ACPProviderCapabilities

    public init(providerName: String, providerVersion: String, models: [ACPModelInfo], capabilities: ACPProviderCapabilities) {
        self.providerName = providerName
        self.providerVersion = providerVersion
        self.models = models
        self.capabilities = capabilities
    }
}

public struct ACPProviderCapabilities: Codable, Sendable {
    public let streaming: Bool
    public let toolUse: Bool
    public let sessions: Bool
    public let vision: Bool

    public init(streaming: Bool = true, toolUse: Bool = true, sessions: Bool = true, vision: Bool = false) {
        self.streaming = streaming
        self.toolUse = toolUse
        self.sessions = sessions
        self.vision = vision
    }
}

public struct ACPModelInfo: Codable, Sendable {
    public let id: String
    public let name: String
    public let contextWindow: Int
    public let capabilities: [String]

    public init(id: String, name: String, contextWindow: Int, capabilities: [String] = []) {
        self.id = id
        self.name = name
        self.contextWindow = contextWindow
        self.capabilities = capabilities
    }
}

// MARK: - Complete Request

public struct ACPCompleteParams: Codable, Sendable {
    public let model: String
    public let messages: [ACPMessageParam]
    public let tools: [ACPToolParam]?
    public let stream: Bool
    public let maxTokens: Int?

    public init(model: String, messages: [ACPMessageParam], tools: [ACPToolParam]? = nil, stream: Bool = true, maxTokens: Int? = nil) {
        self.model = model
        self.messages = messages
        self.tools = tools
        self.stream = stream
        self.maxTokens = maxTokens
    }
}

public struct ACPMessageParam: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ACPToolParam: Codable, Sendable {
    public let name: String
    public let description: String
    public let inputSchema: String

    public init(name: String, description: String, inputSchema: String) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

// MARK: - Session Management

public struct ACPSessionCreateParams: Codable, Sendable {
    public let model: String
    public let systemPrompt: String?

    public init(model: String, systemPrompt: String? = nil) {
        self.model = model
        self.systemPrompt = systemPrompt
    }
}

public struct ACPSessionCreateResult: Codable, Sendable {
    public let sessionId: String

    public init(sessionId: String) {
        self.sessionId = sessionId
    }
}

public struct ACPSessionMessageParams: Codable, Sendable {
    public let sessionId: String
    public let message: ACPMessageParam
    public let tools: [ACPToolParam]?

    public init(sessionId: String, message: ACPMessageParam, tools: [ACPToolParam]? = nil) {
        self.sessionId = sessionId
        self.message = message
        self.tools = tools
    }
}

// MARK: - Stream Events

public struct ACPStreamDelta: Codable, Sendable {
    public let text: String

    public init(text: String) {
        self.text = text
    }
}

public struct ACPStreamToolCall: Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String

    public init(id: String, name: String, arguments: String) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

public struct ACPStreamUsage: Codable, Sendable {
    public let inputTokens: Int
    public let outputTokens: Int

    public init(inputTokens: Int, outputTokens: Int) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

// MARK: - Type-erased Codable wrapper for JSON-RPC params/results

/// A Sendable, Codable wrapper for arbitrary JSON values in ACP protocol messages.
/// Uses a recursive enum instead of `Any` to maintain Sendable conformance.
public enum ACPAnyCodable: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case dictionary([String: ACPAnyCodable])
    case array([ACPAnyCodable])
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) { self = .string(str) }
        else if let bool = try? container.decode(Bool.self) { self = .bool(bool) }
        else if let int = try? container.decode(Int.self) { self = .int(int) }
        else if let double = try? container.decode(Double.self) { self = .double(double) }
        else if let dict = try? container.decode([String: ACPAnyCodable].self) { self = .dictionary(dict) }
        else if let arr = try? container.decode([ACPAnyCodable].self) { self = .array(arr) }
        else { self = .null }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str): try container.encode(str)
        case .int(let int): try container.encode(int)
        case .double(let double): try container.encode(double)
        case .bool(let bool): try container.encode(bool)
        case .dictionary(let dict): try container.encode(dict)
        case .array(let arr): try container.encode(arr)
        case .null: try container.encodeNil()
        }
    }

    /// Encode a Codable value into an ACPAnyCodable for use in protocol messages.
    public static func encode<T: Codable>(_ value: T) throws -> ACPAnyCodable {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(ACPAnyCodable.self, from: data)
    }

    /// Decode an ACPAnyCodable back into a typed Codable value.
    public func decode<T: Codable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }
}
