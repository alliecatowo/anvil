import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers

struct ConversationView: View {
    let session: AgentSession
    @Binding var inputText: String
    @Binding var selectedModelId: String
    let editSuggestions: [CodeEditSuggestion]
    let onSend: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onExport: () -> Void
    let onExportFile: ((SessionExportFormat) -> Void)?
    let onAcceptHunk: (String, String) -> Void  // suggestionId, hunkId
    let onRejectHunk: (String, String) -> Void
    let onAcceptAll: (String) -> Void  // suggestionId
    let onRejectAll: (String) -> Void
    let attachments: [ContextAttachment]
    let onRemoveAttachment: (String) -> Void
    let onAddAttachment: (ContextAttachment) -> Void
    var onSetBudget: ((Decimal?, Bool) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Session header with model picker and session actions
            SessionHeader(
                session: session,
                selectedModelId: $selectedModelId,
                onRename: onRename,
                onDelete: onDelete,
                onExport: onExport,
                onExportFile: onExportFile,
                onSetBudget: onSetBudget
            )

            Divider().overlay(AnvilColor.borderSubtle)

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AnvilSpacing.md) {
                        ForEach(session.messages) { message in
                            MessageBubble(
                                message: message,
                                isStreaming: session.status == .running
                                    && message.role == .assistant
                                    && message.id == session.messages.last?.id
                            )
                            .id(message.id)
                        }

                        // Inline edit suggestions
                        ForEach(editSuggestions) { suggestion in
                            InlineEditView(
                                suggestion: suggestion,
                                onAcceptHunk: { hunkId in onAcceptHunk(suggestion.id, hunkId) },
                                onRejectHunk: { hunkId in onRejectHunk(suggestion.id, hunkId) },
                                onAcceptAll: { onAcceptAll(suggestion.id) },
                                onRejectAll: { onRejectAll(suggestion.id) }
                            )
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

            // Input bar with slash commands, @ references, and context attachments
            InputBar(
                text: $inputText,
                isRunning: session.status == .running,
                attachments: attachments,
                onSend: onSend,
                onRemoveAttachment: onRemoveAttachment,
                onAddAttachment: onAddAttachment
            )
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
    let onExportFile: ((SessionExportFormat) -> Void)?
    var onSetBudget: ((Decimal?, Bool) -> Void)?

    @State private var isEditing = false
    @State private var editName = ""
    @State private var showTokenDetails = false
    @State private var showBudgetSheet = false

    /// Context window limit for the selected model.
    private var contextLimit: Int {
        let model = selectedModelId
        if model.contains("opus") || model.contains("sonnet") { return 200_000 }
        if model.contains("haiku") { return 200_000 }
        if model.contains("gpt-4o") { return 128_000 }
        return 128_000
    }

    var body: some View {
        VStack(spacing: 0) {
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

                // Token usage compact — click to expand
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        showTokenDetails.toggle()
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                        Text(formatTokenCount(session.tokenUsage.totalTokens))
                            .font(AnvilFont.statusBar)
                        Text("$\(NSDecimalNumber(decimal: session.cost).doubleValue, specifier: "%.2f")")
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                    .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)

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
                Button("Set Budget...") {
                    showBudgetSheet = true
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

            // Expandable token usage detail bar
            if showTokenDetails {
                TokenUsageBar(
                    usage: session.tokenUsage,
                    cost: session.cost,
                    contextLimit: contextLimit
                )
                .padding(.horizontal, AnvilSpacing.lg)
                .padding(.bottom, AnvilSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Budget warning banner
            if let usage = session.budgetUsage, usage >= 0.8 {
                CostBudgetBanner(usage: usage, budget: session.costBudget ?? 0, cost: session.cost, hardStop: session.hardStopOnBudget)
            }
        }
        .background(AnvilColor.backgroundSecondary)
        .popover(isPresented: $showBudgetSheet, arrowEdge: .bottom) {
            BudgetSettingPopover(
                currentBudget: session.costBudget,
                hardStop: session.hardStopOnBudget
            ) { budget, hardStop in
                onSetBudget?(budget, hardStop)
                showBudgetSheet = false
            }
        }
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

    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}

// MARK: - Cost Budget Banner

struct CostBudgetBanner: View {
    let usage: Double
    let budget: Decimal
    let cost: Decimal
    let hardStop: Bool

    private var isExceeded: Bool { usage >= 1.0 }
    private var bannerColor: Color { isExceeded ? AnvilColor.accentRed : AnvilColor.accentAmber }

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: isExceeded ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(bannerColor)

            if isExceeded {
                Text("Budget exceeded")
                    .font(AnvilFont.statusBar)
                    .foregroundStyle(bannerColor)
                if hardStop {
                    Text("— session paused")
                        .font(AnvilFont.statusBar)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
            } else {
                Text("\(Int(usage * 100))% of budget used")
                    .font(AnvilFont.statusBar)
                    .foregroundStyle(bannerColor)
            }

            Spacer()

            Text("$\(NSDecimalNumber(decimal: cost).doubleValue, specifier: "%.2f") / $\(NSDecimalNumber(decimal: budget).doubleValue, specifier: "%.2f")")
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.textSecondary)
        }
        .padding(.horizontal, AnvilSpacing.lg)
        .padding(.vertical, AnvilSpacing.xs)
        .background(bannerColor.opacity(0.08))
    }
}

// MARK: - Budget Setting Popover

struct BudgetSettingPopover: View {
    let currentBudget: Decimal?
    let hardStop: Bool
    let onSave: (Decimal?, Bool) -> Void

    @State private var budgetText: String = ""
    @State private var hardStopEnabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            Text("Session Budget")
                .font(AnvilFont.sidebarHeader)
                .foregroundStyle(AnvilColor.textPrimary)

            HStack(spacing: AnvilSpacing.xs) {
                Text("$")
                    .font(AnvilFont.statusBar)
                    .foregroundStyle(AnvilColor.textSecondary)
                TextField("e.g. 5.00", text: $budgetText)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.statusBar)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.backgroundPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )
            }

            Toggle("Hard stop at budget limit", isOn: $hardStopEnabled)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textSecondary)
                .toggleStyle(.checkbox)

            Text("Warnings appear at 80%. Hard stop pauses the session at 100%.")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            HStack {
                Button("Clear") {
                    onSave(nil, false)
                }
                .buttonStyle(.borderless)
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.textTertiary)

                Spacer()

                Button("Save") {
                    let value = Decimal(string: budgetText)
                    onSave(value, hardStopEnabled)
                }
                .buttonStyle(.borderless)
                .font(AnvilFont.statusBar)
                .foregroundStyle(AnvilColor.accentBlue)
            }
        }
        .padding(AnvilSpacing.md)
        .frame(width: 240)
        .onAppear {
            if let budget = currentBudget {
                budgetText = "\(NSDecimalNumber(decimal: budget).doubleValue)"
            }
            hardStopEnabled = hardStop
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: AgentMessage
    var isStreaming: Bool = false

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

            // Content — use streaming-aware rendering for assistant messages
            if message.role == .assistant && !message.content.isEmpty {
                if isStreaming {
                    StreamingMarkdownContent(markdown: message.content)
                        .textSelection(.enabled)
                } else {
                    AnvilMarkdownRenderer(message.content)
                        .textSelection(.enabled)
                }
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

/// Renders markdown with streaming-aware code blocks.
/// Detects in-progress (unclosed) code fences and renders them with StreamingCodeBlock.
struct StreamingMarkdownContent: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    private enum StreamBlock {
        case text(String)
        case codeBlock(code: String, language: String?, isComplete: Bool)
    }

    private func parseBlocks() -> [StreamBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [StreamBlock] = []
        var textBuffer: [String] = []
        var inCodeBlock = false
        var codeLines: [String] = []
        var codeLanguage: String?
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !inCodeBlock && trimmed.hasPrefix("```") {
                // Flush text buffer
                if !textBuffer.isEmpty {
                    blocks.append(.text(textBuffer.joined(separator: "\n")))
                    textBuffer = []
                }
                // Start code block
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeLanguage = lang.isEmpty ? nil : lang
                codeLines = []
                inCodeBlock = true
                i += 1
                continue
            }

            if inCodeBlock {
                if trimmed.hasPrefix("```") {
                    // Close code block
                    blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLanguage, isComplete: true))
                    inCodeBlock = false
                    codeLines = []
                    codeLanguage = nil
                    i += 1
                    continue
                }
                codeLines.append(line)
                i += 1
                continue
            }

            textBuffer.append(line)
            i += 1
        }

        // Handle unclosed code block (still streaming)
        if inCodeBlock {
            blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: codeLanguage, isComplete: false))
        }

        // Flush remaining text
        if !textBuffer.isEmpty {
            blocks.append(.text(textBuffer.joined(separator: "\n")))
        }

        return blocks
    }

    @ViewBuilder
    private func renderBlock(_ block: StreamBlock) -> some View {
        switch block {
        case .text(let text):
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                AnvilMarkdownRenderer(text)
            }
        case .codeBlock(let code, let language, let isComplete):
            StreamingCodeBlock(
                code: code,
                language: language,
                isStreaming: !isComplete
            )
        }
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
    let attachments: [ContextAttachment]
    let onSend: () -> Void
    let onRemoveAttachment: (String) -> Void
    let onAddAttachment: (ContextAttachment) -> Void

    @State private var showSlashMenu = false
    @State private var showAtPopup = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Context attachment bar
            ContextAttachmentBar(attachments: attachments, onRemove: onRemoveAttachment)

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
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(AnvilColor.accentBlue.opacity(isDropTargeted ? 0.6 : 0), lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        DispatchQueue.main.async {
                            onAddAttachment(.file(path: url.path))
                        }
                    }
                }
            }
            return true
        }
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
