import Foundation

// MARK: - Zed ACP Protocol Types

/// Result from the `initialize` handshake.
public struct ZedACPInitializeResult: Codable, Sendable {
    public let name: String?
    public let title: String?
    public let version: String?
    public let instructions: String?

    public init(name: String? = nil, title: String? = nil, version: String? = nil, instructions: String? = nil) {
        self.name = name
        self.title = title
        self.version = version
        self.instructions = instructions
    }
}

/// Result from `session/prompt`.
public struct ZedACPPromptResult: Codable, Sendable {
    public let stopReason: String

    public init(stopReason: String) {
        self.stopReason = stopReason
    }
}

// MARK: - Session Updates (discriminated union via `sessionUpdate` field)

/// Streaming updates sent by the agent as `session/update` notifications.
public enum ZedACPSessionUpdate: Sendable {
    case agentMessageChunk(text: String)
    case toolCall(id: String, name: String, status: String)
    case toolCallUpdate(id: String, status: String, content: String?)
    case plan(content: String)
    case availableCommands([String])
    case unknown(type: String)
}

extension ZedACPSessionUpdate {
    /// Parse a `session/update` notification params into a typed update.
    public static func from(params: ACPAnyCodable) -> ZedACPSessionUpdate? {
        guard case .dictionary(let dict) = params,
              case .dictionary(let updateDict)? = dict["sessionUpdate"],
              case .string(let type)? = updateDict["type"] else {
            return nil
        }

        switch type {
        case "agent_message_chunk":
            if case .string(let text)? = updateDict["text"] {
                return .agentMessageChunk(text: text)
            }
        case "tool_call":
            let id = updateDict["id"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
            let name = updateDict["name"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
            let status = updateDict["status"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? "started"
            return .toolCall(id: id, name: name, status: status)
        case "tool_call_update":
            let id = updateDict["id"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? ""
            let status = updateDict["status"].flatMap { if case .string(let s) = $0 { return s } else { return nil } } ?? "running"
            let content = updateDict["content"].flatMap { if case .string(let s) = $0 { return s } else { return nil } }
            return .toolCallUpdate(id: id, status: status, content: content)
        case "plan":
            if case .string(let content)? = updateDict["content"] {
                return .plan(content: content)
            }
        case "available_commands_update":
            if case .array(let arr)? = updateDict["commands"] {
                let commands = arr.compactMap { if case .string(let s) = $0 { return s } else { return nil } }
                return .availableCommands(commands)
            }
        default:
            return .unknown(type: type)
        }
        return nil
    }
}

// MARK: - Permission Request/Response

/// An agent request for user permission before executing a tool.
public struct ZedACPPermissionRequest: Sendable {
    public let toolCallId: String
    public let toolName: String
    public let options: [ZedACPPermissionOption]

    public init(toolCallId: String, toolName: String, options: [ZedACPPermissionOption]) {
        self.toolCallId = toolCallId
        self.toolName = toolName
        self.options = options
    }
}

/// A single permission option presented to the user.
public struct ZedACPPermissionOption: Sendable {
    public let optionId: String
    public let name: String
    public let kind: String

    public init(optionId: String, name: String, kind: String) {
        self.optionId = optionId
        self.name = name
        self.kind = kind
    }
}

/// The client's response to a permission request.
public struct ZedACPPermissionResponse: Sendable {
    public let optionId: String

    public init(optionId: String) {
        self.optionId = optionId
    }
}
