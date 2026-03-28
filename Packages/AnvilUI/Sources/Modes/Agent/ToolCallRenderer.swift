import SwiftUI
import AnvilDomain

// MARK: - Tool Call View

struct ToolCallView: View {
    let toolCall: ToolCall
    var onApprove: ((Bool) -> Void)?
    var onReject: ((Bool) -> Void)?
    @State private var isExpanded = false

    var body: some View {
        GroupBox {
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
                        AnvilButton("Approve", icon: "checkmark", style: .primary) {
                            onApprove?(false)
                        }
                        AnvilButton("Reject", icon: "xmark", style: .destructive) {
                            onReject?(false)
                        }
                    }
                }
            }
        }
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

// MARK: - Tool Approval Banner

struct ToolApprovalBanner: View {
    let toolName: String
    let arguments: String
    let guardrailViolation: String?
    let onApprove: (Bool) -> Void  // Bool = remember
    let onReject: (Bool) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                HStack {
                    Image(systemName: guardrailViolation != nil ? "shield.slash" : "wrench.and.screwdriver")
                        .foregroundStyle(guardrailViolation != nil ? AnvilColor.accentRed : AnvilColor.accentAmber)
                    Text("Tool call requires approval")
                        .font(AnvilFont.sidebarHeader)
                        .foregroundStyle(AnvilColor.textPrimary)
                    Spacer()
                }

                HStack(spacing: AnvilSpacing.sm) {
                    Text(toolName)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AnvilColor.accentPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(arguments.prefix(120))
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(2)
                }

                if let violation = guardrailViolation {
                    HStack(spacing: AnvilSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AnvilColor.accentRed)
                            .font(.system(size: 11))
                        Text(violation)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.accentRed)
                    }
                }

                HStack(spacing: AnvilSpacing.sm) {
                    Button("Approve") { onApprove(false) }
                        .buttonStyle(.bordered)
                        .tint(.green)

                    Button("Always Allow") { onApprove(true) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AnvilColor.accentGreen)

                    Button("Reject") { onReject(false) }
                        .buttonStyle(.bordered)
                        .tint(.red)

                    Button("Always Deny") { onReject(true) }
                        .buttonStyle(.borderless)
                        .foregroundStyle(AnvilColor.accentRed)
                }
            }
        }
    }
}
