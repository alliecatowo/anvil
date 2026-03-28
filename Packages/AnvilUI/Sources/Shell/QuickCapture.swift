import SwiftUI
import AnvilDomain

// MARK: - Capture Type

enum QuickCaptureType: String, CaseIterable {
    case note = "Note"
    case ticket = "Ticket"
    case agent = "Agent"

    var icon: String {
        switch self {
        case .note: "note.text"
        case .ticket: "ticket"
        case .agent: "bolt"
        }
    }

    var hint: String {
        switch self {
        case .note: "Will save as a note"
        case .ticket: "Will create a ticket in Plan"
        case .agent: "Will start an agent session in Build"
        }
    }

    var submitLabel: String {
        switch self {
        case .note: "\u{21B5} Save"
        case .ticket: "\u{21B5} Create Ticket"
        case .agent: "\u{21B5} Start Session"
        }
    }
}

// MARK: - Quick Capture View

public struct QuickCapture: View {
    @EnvironmentObject var appState: AppState
    @State private var text = ""
    @State private var selectedType: QuickCaptureType = .note
    @State private var showSuccess = false
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            // Backdrop -- clear so sidebar remains clickable
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Capture panel
            VStack(spacing: 0) {
                // Input field
                HStack(spacing: AnvilSpacing.sm) {
                    ZStack {
                        if showSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(.green)
                                .frame(width: 20)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Image(systemName: selectedType.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(AnvilColor.accentBlue)
                                .frame(width: 20)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showSuccess)

                    TextField("Quick capture...", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.commandPaletteInput)
                        .foregroundStyle(.primary)
                        .focused($isInputFocused)
                }
                .padding(AnvilSpacing.md)

                // Mode indicator
                HStack {
                    Text(selectedType.hint)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)

                Divider()

                // Type selector buttons
                HStack(spacing: AnvilSpacing.sm) {
                    ForEach(Array(QuickCaptureType.allCases.enumerated()), id: \.element.rawValue) { index, type in
                        QuickCaptureTypeButton(
                            type: type,
                            isSelected: selectedType == type,
                            shortcutIndex: index + 1
                        ) {
                            selectedType = type
                        }
                    }

                    Spacer()

                    // Submit hint
                    Text(selectedType.submitLabel)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
            }
            .frame(width: 500)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20)
        }
        .onAppear {
            isInputFocused = true
        }
        .onKeyPress(.return) {
            save()
            return .handled
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.tab) {
            cycleType()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "1")) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            selectedType = .note
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "2")) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            selectedType = .ticket
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "3")) { keyPress in
            guard keyPress.modifiers.contains(.command) else { return .ignored }
            selectedType = .agent
            return .handled
        }
        .onExitCommand {
            dismiss()
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            dismiss()
            return
        }

        switch selectedType {
        case .note:
            // Notes are captured as backlog tickets with a note prefix
            appState.intentViewModel.createTicket(title: "Note: \(trimmed)", status: "backlog")
            showSuccessThenDismiss()

        case .ticket:
            appState.intentViewModel.createTicket(title: trimmed, status: "todo")
            appState.switchSpace(.plan)
            showSuccessThenDismiss()

        case .agent:
            appState.agentViewModel.startNewSession(
                prompt: trimmed,
                model: appState.agentViewModel.selectedModelId
            )
            appState.switchSpace(.build)
            appState.agentViewModel.showConversation()
            dismiss()
        }
    }

    private func showSuccessThenDismiss() {
        withAnimation {
            showSuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(AnvilAnimation.commandPaletteAppear) {
            appState.isQuickCaptureVisible = false
        }
    }

    private func cycleType() {
        let all = QuickCaptureType.allCases
        guard let idx = all.firstIndex(of: selectedType) else { return }
        let next = all[(idx + 1) % all.count]
        selectedType = next
    }
}

// MARK: - Type Button

struct QuickCaptureTypeButton: View {
    let type: QuickCaptureType
    let isSelected: Bool
    let shortcutIndex: Int
    let action: () -> Void

    @GestureState private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Label(type.rawValue, systemImage: type.icon)
                Text("\u{2318}\(shortcutIndex)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : nil)
        .controlSize(.small)
        .scaleEffect(isPressed ? 0.93 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, pressed, _ in pressed = true }
        )
    }
}
