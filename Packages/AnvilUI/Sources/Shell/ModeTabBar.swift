import SwiftUI

public struct ModeTabBar: View {
    @EnvironmentObject var appState: AppState
    private let compact: Bool

    public init(compact: Bool = false) {
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? AnvilSpacing.sm : AnvilSpacing.md) {
            Picker("Primary Mode", selection: coreModeSelection) {
                ForEach(AnvilMode.coreModes) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: compact ? 280 : 320)

            Divider()
                .frame(height: 18)

            Menu {
                Section("Workspace") {
                    ForEach(AnvilMode.workspaceModes) { mode in
                        Button {
                            appState.switchMode(mode)
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                            if appState.currentMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                Section("Context") {
                    ForEach(AnvilMode.contextModes) { mode in
                        Button {
                            appState.switchMode(mode)
                        } label: {
                            Label(mode.rawValue, systemImage: mode.icon)
                            if appState.currentMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label(workspaceMenuTitle, systemImage: "square.grid.2x2")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.borderlessButton)
            .help("Workspace and Context Views")

            if !compact {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, compact ? 0 : AnvilSpacing.sm)
        .padding(.vertical, compact ? 0 : 6)
        .frame(height: compact ? nil : 40)
        .background {
            if !compact {
                AnvilColor.backgroundToolbar
            }
        }
        .overlay(alignment: .bottom) {
            if !compact {
                Rectangle()
                    .fill(AnvilColor.borderSubtle)
                    .frame(height: 1)
            }
        }
    }

    private var coreModeSelection: Binding<AnvilMode> {
        Binding(
            get: { appState.lastCoreMode },
            set: { appState.switchMode($0) }
        )
    }

    private var workspaceMenuTitle: String {
        if AnvilMode.auxiliaryModes.contains(appState.currentMode) {
            return appState.currentMode.rawValue
        }
        return "Workspaces"
    }
}
