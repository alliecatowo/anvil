import SwiftUI
import AnvilDomain

/// A compact floating chat panel that provides agent access from any space.
/// Slides in from the trailing edge of the window as a 360pt overlay.
struct AgentChatPanel: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var container: DependencyContainer

    @State private var inputText = ""

    private var selectedSession: AgentSession? {
        appState.agentViewModel.selectedSession
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading border
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1)

            VStack(spacing: 0) {
                // MARK: - Header
                panelHeader

                Divider()

                // MARK: - Messages
                if let session = selectedSession {
                    messagesArea(session: session)
                } else {
                    emptyState
                }

                Divider()

                // MARK: - Input
                panelInput
            }
        }
        .frame(width: 360)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header

    private var panelHeader: some View {
        HStack(spacing: AnvilSpacing.sm) {
            // Session picker
            Picker("Session", selection: $appState.agentViewModel.selectedSessionId) {
                Text("No Session")
                    .tag(String?.none)
                ForEach(appState.agentViewModel.sessions) { session in
                    Text(session.displayName)
                        .tag(Optional(session.id))
                        .lineLimit(1)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Running session count badge
            if appState.agentViewModel.sessions.filter({ $0.status == .running }).count > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AnvilColor.accentGreen)
                        .frame(width: 6, height: 6)
                    Text("\(appState.agentViewModel.sessions.filter({ $0.status == .running }).count) active")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentGreen)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AnvilColor.accentGreen.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityLabel("\(appState.agentViewModel.sessions.filter({ $0.status == .running }).count) active sessions")
            }

            // New session button
            Button {
                appState.agentViewModel.startNewSession(
                    prompt: "",
                    model: appState.agentViewModel.selectedModelId
                )
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("New Session")

            // Close button
            Button {
                appState.toggleAgentPanel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Close Agent Panel")
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Messages

    private func messagesArea(session: AgentSession) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                    ForEach(session.messages) { message in
                        compactMessageRow(message: message, session: session)
                            .id(message.id)
                    }

                    if session.status == .running {
                        HStack(spacing: AnvilSpacing.sm) {
                            AnvilLoadingIndicator(size: 12)
                            Text("Thinking...")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentPurple)
                        }
                        .padding(.horizontal, AnvilSpacing.md)
                    }
                }
                .padding(AnvilSpacing.md)
            }
            .onChange(of: session.messages.count) { _, _ in
                if let lastId = session.messages.last?.id {
                    withAnimation(AnvilAnimation.standard) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func compactMessageRow(message: AgentMessage, session: AgentSession) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.sm) {
            // Role indicator
            Circle()
                .fill(message.role == .user ? AnvilColor.accentBlue : AnvilColor.accentPurple)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            Text(message.content)
                .font(AnvilFont.label)
                .foregroundStyle(message.role == .user ? .primary : .secondary)
                .textSelection(.enabled)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Spacer()
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("No active session")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
            Text("Start a new session or select one above.")
                .font(AnvilFont.label)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AnvilSpacing.lg)
    }

    // MARK: - Input

    private var panelInput: some View {
        HStack(spacing: AnvilSpacing.sm) {
            TextField("Ask the agent...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .lineLimit(1...5)
                .onSubmit {
                    sendMessage()
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : AnvilColor.accentBlue
                    )
            }
            .buttonStyle(.borderless)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        if selectedSession == nil {
            // Auto-create a session when sending the first message
            appState.agentViewModel.startNewSession(
                prompt: text,
                model: appState.agentViewModel.selectedModelId,
                container: container
            )
        } else {
            appState.agentViewModel.inputText = text
            appState.agentViewModel.sendMessage(container: container, appState: appState)
        }
        inputText = ""
    }
}
