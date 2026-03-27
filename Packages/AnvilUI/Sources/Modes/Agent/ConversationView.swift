import SwiftUI
import AnvilDomain

struct ConversationView: View {
    let session: AgentSession
    @Binding var inputText: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Session header
            SessionHeader(session: session)

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
            }

            Divider().overlay(AnvilColor.borderSubtle)

            // Input bar
            InputBar(text: $inputText, isRunning: session.status == .running, onSend: onSend)
        }
        .background(AnvilColor.backgroundPrimary)
    }
}

// MARK: - Session Header

struct SessionHeader: View {
    let session: AgentSession

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(session.model)
                .font(AnvilFont.sidebarHeader)
                .foregroundStyle(AnvilColor.textPrimary)

            AnvilBadge(text: session.status.rawValue, color: statusColor)

            Spacer()

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

            // Content
            Text(message.content)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .textSelection(.enabled)

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

    var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            TextField("Message the agent...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
                .lineLimit(1...5)
                .onSubmit(onSend)

            Button(action: onSend) {
                Image(systemName: isRunning ? "pause.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(text.isEmpty ? AnvilColor.textTertiary : AnvilColor.accentBlue)
            }
            .buttonStyle(.plain)
            .disabled(text.isEmpty && !isRunning)
        }
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
    }
}
