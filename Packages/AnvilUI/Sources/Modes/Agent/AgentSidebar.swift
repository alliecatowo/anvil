import SwiftUI
import AnvilDomain

struct AgentSidebar: View {
    @ObservedObject var viewModel: AgentViewModel

    var body: some View {
        VStack(spacing: 0) {
            // New session button
            Button(action: {
                viewModel.startNewSession(prompt: "", model: "claude-sonnet-4-6")
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AnvilColor.accentPurple)
                    Text("New Session")
                        .font(AnvilFont.sidebarItem)
                    Spacer()
                }
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
                .contentShape(Rectangle())
                .background(AnvilColor.backgroundTertiary.opacity(0.001)) // Ensure hit testing
            }
            .buttonStyle(.borderless)

            Divider().overlay(AnvilColor.borderSubtle)

            // Session list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.sessions) { session in
                        AgentSessionRow(
                            session: session,
                            isSelected: session.id == viewModel.selectedSessionId
                        )
                        .onTapGesture {
                            viewModel.selectedSessionId = session.id
                        }
                    }
                }
            }
        }
    }
}

struct AgentSessionRow: View {
    let session: AgentSession
    let isSelected: Bool

    var body: some View {
        AnvilListItem(
            icon: statusIcon,
            title: session.workItemId ?? "Session",
            subtitle: session.model,
            tag: session.status.rawValue,
            tagColor: statusColor,
            isSelected: isSelected,
            isCompact: false
        )
    }

    var statusIcon: String {
        switch session.status {
        case .running: "circle.fill"
        case .completed: "checkmark.circle"
        case .failed: "xmark.circle"
        case .paused: "pause.circle"
        default: "circle"
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
}
