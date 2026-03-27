import SwiftUI
import AnvilDomain

struct ConversationView: View {
    let session: AgentSession
    @Binding var inputText: String
    @Binding var selectedModelId: String
    let onSend: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Session header with model picker and session actions
            SessionHeader(
                session: session,
                selectedModelId: $selectedModelId,
                onRename: onRename,
                onDelete: onDelete,
                onExport: onExport
            )

            Divider().overlay(AnvilColor.borderSubtle)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AnvilSpacing.md) {
                        ForEach(session.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if session.status == .running {
                            HStack(spacing: AnvilSpacing.sm) {
                                AnvilLoadingIndicator(size: 14)
                                Text("Thinking...")
                                    .font(AnvilFont.body)
                                    .foregroundStyle(AnvilColor.accentPurple)
                            }
                            .padding(.horizontal, AnvilSpacing.lg)
                        }
                    }
                    .padding(AnvilSpacing.lg)
                }
                .onChange(of: session.messages.count) { _, _ in
                    if let lastId = session.messages.last?.id {
                        withAnimation(AnvilAnimation.standard) {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }
            }

            Divider().overlay(AnvilColor.borderSubtle)

            // Input bar with slash commands and @ references
            InputBar(text: $inputText, isRunning: session.status == .running, onSend: onSend)
        }
        .background(AnvilColor.backgroundPrimary)
    }
}

// MARK: - Session Header

struct SessionHeader: View {
    let session: AgentSession
    @Binding var selectedModelId: String
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    @State private var isEditing = false
    @State private var editName = ""

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            if isEditing {
                TextField("Session name", text: $editName)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .frame(maxWidth: 200)
                    .onSubmit {
                        onRename(editName)
                        isEditing = false
                    }
            } else {
                Text(session.displayName)
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .onTapGesture(count: 2) {
                        editName = session.displayName
                        isEditing = true
                    }
            }

            AnvilBadge(text: session.status.rawValue, color: statusColor)

            Spacer()

            // Model picker
            ModelPicker(selectedModelId: $selectedModelId)

            // Token usage
            HStack(spacing: AnvilSpacing.xxs) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 10))
                Text("\(session.tokenUsage.inputTokens)")
                    .font(AnvilFont.statusBar)
                Image(systemName: "arrow.up.circle")
                    .font(.system(size: 10))
                Text("\(session.tokenUsage.outputTokens)")
                    .font(AnvilFont.statusBar)
            }
            .foregroundStyle(AnvilColor.textTertiary)

            // Cost
            Text("$\(NSDecimalNumber(decimal: session.cost).doubleValue, specifier: "%.2f")")
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.textSecondary)

            // Session actions menu
            Menu {
                Button("Rename Session") {
                    editName = session.displayName
                    isEditing = true
                }
                Button("Export to Markdown") {
                    onExport()
                }
                Divider()
                Button("Delete Session", role: .destructive) {
                    onDelete()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 14))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundSecondary)
    }

    var statusColor: Color {
        switch session.status {
        case .running: AnvilColor.accentGreen
        case .completed: AnvilColor.accentBlue
        case .failed: AnvilColor.accentRed
        case .paused: AnvilColor.accentAmber
        default: AnvilColor.textTertiary
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AgentMessage

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            // Role header
            HStack {
                Image(systemName: message.role == .user ? "person.circle" : "cpu")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(message.role == .user ? AnvilColor.accentBlue : AnvilColor.accentPurple)

                Text(message.role == .user ? "You" : "Agent")
                    .font(AnvilFont.sidebarHeader)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                Text(message.timestamp, style: .time)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Content — use markdown renderer for assistant, plain text for user
            if message.role == .assistant && !message.content.isEmpty {
                AnvilMarkdownRenderer(message.content)
                    .textSelection(.enabled)
            } else if !message.content.isEmpty {
                Text(message.content)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .textSelection(.enabled)
            }

            // Tool calls
            ForEach(message.toolCalls) { toolCall in
                ToolCallView(toolCall: toolCall)
            }
        }
        .padding(AnvilSpacing.md)
        .background(message.role == .user ? AnvilColor.backgroundSecondary : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            Button {
                withAnimation(AnvilAnimation.standard) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: toolCallIcon)
                        .font(.system(size: 11))
                    Text(toolCall.name)
                        .font(AnvilFont.code)

                    statusIndicator

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(AnvilColor.textSecondary)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xs)
            }
            .buttonStyle(.plain)

            if isExpanded, let result = toolCall.result {
                Text(result.content)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .padding(AnvilSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AnvilColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .lineLimit(20)
            }

            // Approve/Reject for pending tool calls
            if toolCall.status == .pending {
                HStack(spacing: AnvilSpacing.sm) {
                    AnvilButton("Approve", icon: "checkmark", style: .primary) {}
                    AnvilButton("Reject", icon: "xmark", style: .destructive) {}
                }
            }
        }
        .padding(AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AnvilColor.borderSubtle, lineWidth: 1)
        )
    }

    var toolCallIcon: String {
        switch toolCall.name {
        case "read_file": "doc.text"
        case "write_file", "edit_file": "pencil"
        case "terminal": "terminal"
        case "search", "grep": "magnifyingglass"
        default: "wrench"
        }
    }

    @ViewBuilder
    var statusIndicator: some View {
        switch toolCall.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AnvilColor.accentGreen)
                .font(.system(size: 10))
        case .running:
            AnvilLoadingIndicator(size: 10)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AnvilColor.accentRed)
                .font(.system(size: 10))
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(AnvilColor.accentAmber)
                .font(.system(size: 10))
        default:
            EmptyView()
        }
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    let isRunning: Bool
    let onSend: () -> Void

    @State private var showSlashMenu = false
    @State private var showAtPopup = false

    var body: some View {
        VStack(spacing: 0) {
            // Slash command popup
            if showSlashMenu {
                HStack {
                    SlashCommandMenu(filter: text) { command in
                        text = command.name + " "
                        showSlashMenu = false
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // @ reference popup
            if showAtPopup {
                HStack {
                    AtReferencePopup(filter: currentAtToken) { ref in
                        replaceCurrentAtToken(with: ref.prefix)
                        showAtPopup = false
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: AnvilSpacing.sm) {
                // Sparkles button for AI quick actions
                SparklesButton()

                TextField("Message the agent...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .lineLimit(1...5)
                    .onSubmit(onSend)
                    .onChange(of: text) { _, newValue in
                        withAnimation(AnvilAnimation.standard) {
                            showSlashMenu = newValue.hasPrefix("/") && !newValue.contains(" ")
                            showAtPopup = detectAtToken(in: newValue)
                        }
                    }

                Button(action: onSend) {
                    Image(systemName: isRunning ? "pause.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(text.isEmpty ? AnvilColor.textTertiary : AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty && !isRunning)
            }
            .padding(AnvilSpacing.md)
        }
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - @ token detection

    private var currentAtToken: String {
        guard let atRange = text.range(of: "@[^\\s]*$", options: .regularExpression) else { return "" }
        return String(text[atRange])
    }

    private func detectAtToken(in value: String) -> Bool {
        value.range(of: "@[^\\s]*$", options: .regularExpression) != nil
    }

    private func replaceCurrentAtToken(with replacement: String) {
        if let atRange = text.range(of: "@[^\\s]*$", options: .regularExpression) {
            var updated = text
            updated.replaceSubrange(atRange, with: replacement)
            text = updated
        }
    }
}

// MARK: - Sparkles Button

struct SparklesButton: View {
    @State private var isShowingMenu = false

    var body: some View {
        Menu {
            Button { } label: {
                Label("Review Current Branch", systemImage: "checkmark.circle")
            }
            Button { } label: {
                Label("Explain Selection", systemImage: "text.bubble")
            }
            Button { } label: {
                Label("Fix Current Error", systemImage: "wrench")
            }
            Button { } label: {
                Label("Generate Tests", systemImage: "testtube.2")
            }
            Divider()
            Button { } label: {
                Label("Auto-Commit", systemImage: "arrow.up.circle")
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AnvilColor.accentPurple)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("AI Actions")
    }
}
