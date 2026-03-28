import SwiftUI
import AnvilDomain

// MARK: - Capture Type

enum QuickCaptureType: String, CaseIterable {
    case task = "Task"
    case note = "Note"
    case ticket = "Ticket"

    var icon: String {
        switch self {
        case .task: "checkmark.circle"
        case .note: "note.text"
        case .ticket: "ticket"
        }
    }
}

// MARK: - Quick Capture View

public struct QuickCapture: View {
    @EnvironmentObject var appState: AppState
    @State private var text = ""
    @State private var selectedType: QuickCaptureType = .task
    @FocusState private var isInputFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            // Backdrop — clear so sidebar remains clickable
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
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 15))
                        .foregroundStyle(AnvilColor.accentBlue)
                        .frame(width: 20)

                    TextField("Quick capture...", text: $text)
                        .textFieldStyle(.plain)
                        .font(AnvilFont.commandPaletteInput)
                        .foregroundStyle(.primary)
                        .focused($isInputFocused)
                }
                .padding(AnvilSpacing.md)

                Divider()

                // Type selector buttons
                HStack(spacing: AnvilSpacing.sm) {
                    ForEach(QuickCaptureType.allCases, id: \.rawValue) { type in
                        QuickCaptureTypeButton(
                            type: type,
                            isSelected: selectedType == type
                        ) {
                            selectedType = type
                        }
                    }

                    Spacer()

                    // Submit hint
                    Text("↵ Save")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.sm)
            }
            .frame(width: 500)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.3), radius: 20)
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
        case .task, .ticket:
            appState.intentViewModel.createTicket(title: trimmed, status: "todo")
        case .note:
            // Notes are captured as backlog tickets with a note prefix
            appState.intentViewModel.createTicket(title: "Note: \(trimmed)", status: "backlog")
        }

        dismiss()
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(type.rawValue, systemImage: type.icon)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : nil)
        .controlSize(.small)
    }
}
