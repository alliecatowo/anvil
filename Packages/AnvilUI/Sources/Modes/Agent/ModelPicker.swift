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

    /// Build a unified model list from dynamic provider models (if any) merged with the static fallback.
    /// Dynamic models take precedence when IDs overlap.
    static func merged(dynamicModels: [ModelOption]) -> [ModelOption] {
        guard !dynamicModels.isEmpty else { return builtIn }
        var seen = Set<String>()
        var result: [ModelOption] = []
        // Dynamic models first
        for m in dynamicModels {
            if seen.insert(m.id).inserted {
                result.append(m)
            }
        }
        // Fill in any built-in models not already present
        for m in builtIn {
            if seen.insert(m.id).inserted {
                result.append(m)
            }
        }
        return result
    }
}

struct ModelPicker: View {
    @Binding var selectedModelId: String
    var onModelChange: ((String) -> Void)?
    /// Dynamic models supplied by connected providers. When empty, falls back to static list.
    var dynamicModels: [ModelOption] = []

    private var allModels: [ModelOption] {
        ModelOption.merged(dynamicModels: dynamicModels)
    }

    private var selectedModel: ModelOption {
        allModels.first { $0.id == selectedModelId } ?? allModels.first ?? ModelOption.builtIn[0]
    }

    /// Provider icon mapping
    private static func providerIcon(for provider: String) -> String {
        switch provider.lowercased() {
        case "anthropic": return "brain.head.profile"
        case "openai": return "circle.hexagongrid"
        case "ollama": return "server.rack"
        default: return "cpu"
        }
    }

    var body: some View {
        Menu {
            // Group by provider
            let grouped = Dictionary(grouping: allModels, by: \.provider)
            let sortedProviders = grouped.keys.sorted()

            ForEach(sortedProviders, id: \.self) { provider in
                Section {
                    ForEach(grouped[provider] ?? []) { model in
                        Button {
                            selectedModelId = model.id
                            onModelChange?(model.id)
                        } label: {
                            HStack {
                                if model.id == selectedModelId {
                                    Image(systemName: "checkmark")
                                }
                                Image(systemName: ModelPicker.providerIcon(for: model.provider))
                                    .font(.system(size: 10))
                                Text(model.name)
                            }
                        }
                    }
                } header: {
                    Label(provider, systemImage: ModelPicker.providerIcon(for: provider))
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
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
