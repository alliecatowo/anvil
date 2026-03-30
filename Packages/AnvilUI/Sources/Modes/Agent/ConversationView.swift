import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers

struct ConversationView: View {
    let session: AgentSession
    @Binding var inputText: String
    @Binding var selectedModelId: String
    let editSuggestions: [CodeEditSuggestion]
    let queuedCount: Int
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
    var onSetAutonomy: ((AutonomyLevel) -> Void)?
    var onModelChange: ((String) -> Void)?
    var guardrailCount: Int = 0
    var pendingApproval: AgentViewModel.PendingToolApproval?
    var onApproveToolCall: ((Bool) -> Void)?
    var onRejectToolCall: ((Bool) -> Void)?
    var onCreatePR: (() -> Void)?
    var plan: AgentPlan?
    var onApprovePlan: (() -> Void)?
    var onCancelPlan: (() -> Void)?
    var onSkipPlanStep: ((String) -> Void)?
    var onAnnotatePlanStep: ((String, String) -> Void)?
    var onReorderPlanStep: ((String, Int) -> Void)?
    var onAddPlanStep: ((String, String?) -> Void)?
    var onRemovePlanStep: ((String) -> Void)?
    var onSendToBackground: (() -> Void)?
    var onToggleAgentPanel: (() -> Void)?
    var isAgentPanelVisible: Bool = false
    var autoContextFiles: [AutoContextChipData] = []
    var onDismissAutoContext: ((String) -> Void)?
    var onAcceptAutoContext: ((String) -> Void)?
    var contextResolver: ContextSlashResolver = .empty
    var onForkFromMessage: ((Int) -> Void)?

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
                onSetBudget: onSetBudget,
                onSetAutonomy: onSetAutonomy,
                onModelChange: onModelChange,
                guardrailCount: guardrailCount,
                onCreatePR: onCreatePR,
                onSendToBackground: onSendToBackground,
                onToggleAgentPanel: onToggleAgentPanel,
                isAgentPanelVisible: isAgentPanelVisible
            )

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AnvilSpacing.md) {
                        ForEach(Array(session.messages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(
                                message: message,
                                isStreaming: session.status == .running
                                    && message.role == .assistant
                                    && message.id == session.messages.last?.id,
                                onApproveToolCall: onApproveToolCall,
                                onRejectToolCall: onRejectToolCall
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .contextMenu {
                                Button {
                                    onForkFromMessage?(index)
                                } label: {
                                    Label("Fork from here", systemImage: "arrow.triangle.branch")
                                }

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.content, forType: .string)
                                } label: {
                                    Label("Copy Message", systemImage: "doc.on.doc")
                                }
                            }
                        }
                        .animation(.spring(response: 0.35, dampingFraction: 0.78), value: session.messages.count)

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

            // Agent plan view (shown when a plan exists)
            if let plan = plan {
                AgentPlanView(
                    plan: plan,
                    onApprove: { onApprovePlan?() },
                    onCancel: { onCancelPlan?() },
                    onSkipStep: { stepId in onSkipPlanStep?(stepId) },
                    onAnnotateStep: { stepId, text in onAnnotatePlanStep?(stepId, text) },
                    onReorderStep: { stepId, newOrder in onReorderPlanStep?(stepId, newOrder) },
                    onAddStep: { title, afterId in onAddPlanStep?(title, afterId) },
                    onRemoveStep: { stepId in onRemovePlanStep?(stepId) }
                )
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Tool approval banner (shown when a tool call needs user decision)
            if let approval = pendingApproval {
                ToolApprovalBanner(
                    toolName: approval.toolName,
                    arguments: approval.arguments,
                    guardrailViolation: approval.guardrailViolation,
                    onApprove: { remember in onApproveToolCall?(remember) },
                    onReject: { remember in onRejectToolCall?(remember) }
                )
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            Divider()

            // Input bar with slash commands, @ references, and context attachments
            InputBar(
                text: $inputText,
                isRunning: session.status == .running,
                queuedCount: queuedCount,
                attachments: attachments,
                onSend: onSend,
                onRemoveAttachment: onRemoveAttachment,
                onAddAttachment: onAddAttachment,
                autoContextFiles: autoContextFiles,
                onDismissAutoContext: onDismissAutoContext,
                onAcceptAutoContext: onAcceptAutoContext,
                contextResolver: contextResolver
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
    var onSetAutonomy: ((AutonomyLevel) -> Void)?
    var onModelChange: ((String) -> Void)?
    let guardrailCount: Int
    var onCreatePR: (() -> Void)?
    var onSendToBackground: (() -> Void)?
    var onToggleAgentPanel: (() -> Void)?
    var isAgentPanelVisible: Bool = false

    @State private var isEditing = false
    @State private var editName = ""
    @State private var showTokenDetails = false
    @State private var showBudgetSheet = false
    @State private var isStatusPulsing = false

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
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 2)
                            .scaleEffect(isStatusPulsing ? 1.6 : 1.0)
                            .opacity(isStatusPulsing ? 0 : 0.6)
                            .animation(
                                .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                                value: isStatusPulsing
                            )
                    )
                    .onAppear { isStatusPulsing = true }
                    .accessibilityHidden(true)

                if isEditing {
                    TextField("Session name", text: $editName)
                        .textFieldStyle(.roundedBorder)
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

                // Create PR button — only shown when session is complete
                if session.status == .completed, let createPR = onCreatePR {
                    Button {
                        createPR()
                    } label: {
                        Label("Create PR", systemImage: "arrow.triangle.pull")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                // Send to background button — shown when session is running
                if session.status == .running, let sendBg = onSendToBackground {
                    Button {
                        sendBg()
                    } label: {
                        Label("Background", systemImage: "arrow.down.to.line")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Send this session to the background")
                }

                // Model picker
                ModelPicker(selectedModelId: $selectedModelId, onModelChange: onModelChange)
                    .accessibilityLabel("AI model selector")

                // Autonomy level picker
                AutonomyPicker(level: session.autonomyLevel, onChange: onSetAutonomy)

                // Guardrail indicator
                if guardrailCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 10))
                        Text("\(guardrailCount)")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentAmber)
                    .help("\(guardrailCount) guardrail\(guardrailCount == 1 ? "" : "s") active")
                }

                // Token usage compact — click to expand
                Button {
                    withAnimation(AnvilAnimation.standard) {
                        showTokenDetails.toggle()
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 10))
                            .accessibilityHidden(true)
                        Text(formatTokenCount(session.tokenUsage.totalTokens))
                            .font(AnvilFont.statusBar)
                        Text("$\(NSDecimalNumber(decimal: session.cost).doubleValue, specifier: "%.2f")")
                            .font(AnvilFont.statusBar)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                    .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Token usage")

                if let onToggleAgentPanel {
                    Button {
                        onToggleAgentPanel()
                    } label: {
                        Label("Info", systemImage: isAgentPanelVisible ? "info.circle.fill" : "info.circle")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help(isAgentPanelVisible ? "Hide Build Inspector" : "Show Build Inspector")
                    .accessibilityLabel(isAgentPanelVisible ? "Hide Build Inspector" : "Show Build Inspector")
                    .accessibilityIdentifier("agent.conversation.toggle-sidebar")
                    .accessibilityAddTraits(.isButton)
                }

            // Session actions menu
            Menu {
                Button("Rename Session") {
                    editName = session.displayName
                    isEditing = true
                }
                Menu("Export") {
                    Button("Copy as Markdown") {
                        onExport()
                    }
                    Divider()
                    Button("Save as Markdown...") {
                        onExportFile?(.markdown)
                    }
                    Button("Save as JSON...") {
                        onExportFile?(.json)
                    }
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
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.statusBar)
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

// MARK: - Autonomy Picker

struct AutonomyPicker: View {
    let level: AutonomyLevel
    let onChange: ((AutonomyLevel) -> Void)?

    var body: some View {
        Menu {
            ForEach(AutonomyLevel.allCases, id: \.self) { option in
                Button {
                    onChange?(option)
                } label: {
                    HStack {
                        if option == level {
                            Image(systemName: "checkmark")
                        }
                        Text(option.displayName)
                        Text("- \(option.description)")
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: autonomyIcon)
                    .font(.system(size: 10))
                Text(level.displayName)
                    .font(AnvilFont.label)
            }
            .foregroundStyle(autonomyColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(autonomyColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Autonomy: \(level.description)")
    }

    private var autonomyIcon: String {
        switch level {
        case .ask: return "hand.raised"
        case .review: return "eye"
        case .auto: return "bolt"
        }
    }

    private var autonomyColor: Color {
        switch level {
        case .ask: return AnvilColor.accentBlue
        case .review: return AnvilColor.accentAmber
        case .auto: return AnvilColor.accentGreen
        }
    }
}
