import SwiftUI
import AnvilDomain
import AnvilApplication
import UniformTypeIdentifiers
import UserNotifications
import os.log

private let logger = Logger(subsystem: "com.anvil.app", category: "AgentViewModel")

public enum SessionExportFormat {
    case markdown, json

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .json: "json"
        }
    }
}

@MainActor
public final class AgentViewModel: ObservableObject {
    @Published public var sessions: [AgentSession] = []
    @Published public var selectedSessionId: String?
    @Published public var isLaunchSheetPresented = false
    @Published public var inputText = ""
    @Published public var selectedModelId = "claude-sonnet-4-6"
    @Published public var editSuggestions: [String: [CodeEditSuggestion]] = [:]
    @Published public var contextAttachments: [ContextAttachment] = []
    @Published public var queuedMessages: [String] = []
    @Published public var toolPermissions: ToolPermissionStore = ToolPermissionStore()
    @Published public var guardrails: AgentGuardrails = AgentGuardrails()
    @Published public var pendingToolApproval: PendingToolApproval?

    public struct PendingToolApproval: Identifiable {
        public let id = UUID().uuidString
        public let sessionId: String
        public let toolName: String
        public let arguments: String
        public let guardrailViolation: String?
    }

    public enum AgentViewMode: Equatable {
        case conversation
        case dashboard
        case synthesisRoom(String)
    }

    @Published public var viewMode: AgentViewMode = .conversation
    @Published public var synthesisRooms: [SynthesisRoom] = []
    @Published public var sessionLinks: [SessionLink] = []
    @Published public var dashboardSelectedSessionIds: Set<String> = []

    public var onFilePersisted: ((String) -> Void)?

    public var selectedSession: AgentSession? {
        sessions.first { $0.id == selectedSessionId }
    }

    public init() {
        logger.info("AgentViewModel initialized")
    }

    #if DEBUG
    static func withSampleData() -> AgentViewModel {
        let vm = AgentViewModel()
        let sampleMessages = [
            AgentMessage(role: .user, content: "Fix the authentication bug in the login flow"),
            AgentMessage(role: .assistant, content: "I'll start by examining the auth module to understand the current login flow.\n\nLet me read the relevant files...", toolCalls: [
                ToolCall(name: "read_file", arguments: "{\"path\": \"src/auth/handler.ts\"}", status: .completed, result: ToolResult(content: "// Auth handler with 142 lines...", type: .text)),
            ]),
            AgentMessage(role: .assistant, content: "I found the issue. The token validation is checking expiry against UTC but the token was issued with local time. Let me fix this."),
        ]
        let session = AgentSession(
            providerId: "anthropic",
            model: "claude-opus-4-6",
            status: .completed,
            workItemId: "ANV-42",
            tokenUsage: TokenUsage(inputTokens: 12500, outputTokens: 3200),
            cost: 0.42,
            messages: sampleMessages
        )
        vm.sessions = [session]
        vm.selectedSessionId = session.id
        return vm
    }
    #endif
}
