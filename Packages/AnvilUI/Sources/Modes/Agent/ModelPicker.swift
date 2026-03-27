import SwiftUI
import AnvilDomain

struct ModelOption: Identifiable {
    let id: String
    let name: String
    let provider: String
    let icon: String

    static let builtIn: [ModelOption] = [
        ModelOption(id: "claude-opus-4-6", name: "Claude Opus 4.6", provider: "Anthropic", icon: "brain.head.profile"),
        ModelOption(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", provider: "Anthropic", icon: "brain.head.profile"),
        ModelOption(id: "claude-haiku-4-5", name: "Claude Haiku 4.5", provider: "Anthropic", icon: "brain.head.profile"),
        ModelOption(id: "gpt-4o", name: "GPT-4o", provider: "OpenAI", icon: "circle.hexagongrid"),
        ModelOption(id: "llama-3.3-70b", name: "Llama 3.3 70B", provider: "Ollama", icon: "server.rack"),
    ]
}

struct ModelPicker: View {
    @Binding var selectedModelId: String
    @State private var isExpanded = false

    private var selectedModel: ModelOption {
        ModelOption.builtIn.first { $0.id == selectedModelId } ?? ModelOption.builtIn[0]
    }

    var body: some View {
        Menu {
            ForEach(ModelOption.builtIn) { model in
                Button {
                    selectedModelId = model.id
                } label: {
                    HStack {
                        if model.id == selectedModelId {
                            Image(systemName: "checkmark")
                        }
                        Text(model.name)
                        Text("(\(model.provider))")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: selectedModel.icon)
                    .font(.system(size: 11))
                Text(selectedModel.name)
                    .font(AnvilFont.label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(AnvilColor.textSecondary)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xxs)
            .background(AnvilColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
