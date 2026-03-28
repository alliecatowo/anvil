import SwiftUI
import AnvilDomain

struct BuildSidebar: View {
    @EnvironmentObject var appState: AppState

    enum BuildSection: String, CaseIterable {
        case sessions = "Sessions"
        case files = "Files"
        case data = "Data"
    }

    @State private var activeSection: BuildSection = .sessions

    var body: some View {
        VStack(spacing: 0) {
            // Section picker at top
            Picker("Section", selection: $activeSection) {
                ForEach(BuildSection.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Build Sidebar Section")
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            // Section content
            switch activeSection {
            case .sessions:
                AgentSidebar(viewModel: appState.agentViewModel)
            case .files:
                EditorSidebar(viewModel: appState.editorViewModel)
            case .data:
                Text("No connections configured")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
