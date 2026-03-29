import AppKit
import SwiftUI
import Combine
import AnvilACP

// MARK: - Settings Model

@MainActor
public class AnvilSettings: ObservableObject {
    public static let shared = AnvilSettings()

    private let defaults = UserDefaults.standard

    @Published public var defaultMode: String {
        didSet { defaults.set(defaultMode, forKey: "defaultMode") }
    }
    @Published public var codeFontSize: Double {
        didSet { defaults.set(codeFontSize, forKey: "codeFontSize") }
    }
    @Published public var sidebarWidth: Double {
        didSet { defaults.set(sidebarWidth, forKey: "sidebarWidth") }
    }
    @Published public var showLineNumbers: Bool {
        didSet { defaults.set(showLineNumbers, forKey: "showLineNumbers") }
    }
    @Published public var showMinimap: Bool {
        didSet { defaults.set(showMinimap, forKey: "showMinimap") }
    }
    @Published public var autoSave: Bool {
        didSet { defaults.set(autoSave, forKey: "autoSave") }
    }
    @Published public var projectDirectory: String {
        didSet { defaults.set(projectDirectory, forKey: "projectDirectory") }
    }

    public init() {
        self.defaultMode = defaults.string(forKey: "defaultMode") ?? "Agent"
        self.codeFontSize = defaults.object(forKey: "codeFontSize") as? Double ?? 12
        self.sidebarWidth = defaults.object(forKey: "sidebarWidth") as? Double ?? 260
        self.showLineNumbers = defaults.object(forKey: "showLineNumbers") as? Bool ?? true
        self.showMinimap = defaults.bool(forKey: "showMinimap")
        self.autoSave = defaults.object(forKey: "autoSave") as? Bool ?? true
        self.projectDirectory = defaults.string(forKey: "projectDirectory") ?? ""
    }
}

// MARK: - Settings Window

public struct SettingsWindow: View {
    public init() {}

    public var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ProviderSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "cpu")
                }

            IntegrationSettingsView()
                .tabItem {
                    Label("Integrations", systemImage: "powerplug")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            KeybindingSettingsView()
                .tabItem {
                    Label("Keybindings", systemImage: "keyboard")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 640, height: 500)
    }
}

// MARK: - General Tab

struct GeneralSettingsView: View {
    @StateObject private var settings = AnvilSettings.shared
    @State private var selectedMode: AnvilSpace = .build
    @AppStorage("appearance_mode") private var appearanceMode: String = "system"

    var body: some View {
        Form {
            Section("Project") {
                HStack {
                    Text(settings.projectDirectory.isEmpty ? "No directory selected" : settings.projectDirectory)
                        .foregroundStyle(settings.projectDirectory.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose...") {
                        chooseProjectDirectory()
                    }
                }
            }

            Section("Defaults") {
                Picker("Default Space", selection: $selectedMode) {
                    ForEach(AnvilSpace.allCases) { space in
                        Text(space.rawValue).tag(space)
                    }
                }
                .onChange(of: selectedMode) { _, newValue in
                    settings.defaultMode = newValue.rawValue
                }

                Toggle("Auto-save", isOn: $settings.autoSave)
            }

            Section("Appearance") {
                Picker("Theme", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .onChange(of: appearanceMode) { _, newValue in
                    applyAppearance(newValue)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            selectedMode = AnvilSpace(rawValue: settings.defaultMode) ?? .build
            applyAppearance(appearanceMode)
        }
    }

    private func chooseProjectDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose default project directory"
        if panel.runModal() == .OK, let url = panel.url {
            settings.projectDirectory = url.path
        }
    }

    private func applyAppearance(_ mode: String) {
        switch mode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

// MARK: - Providers Tab

struct ProviderSettingsView: View {
    @EnvironmentObject private var container: DependencyContainer
    @State private var showingAddSheet = false
    @State private var editingProvider: DependencyContainer.ProviderConfig?

    var body: some View {
        VStack(spacing: 0) {
            if container.configuredProviders.isEmpty {
                ContentUnavailableView {
                    Label("No Providers", systemImage: "cpu")
                } description: {
                    Text("Add an ACP provider to get started.")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(sortedProviders, id: \.providerId) { config in
                        ProviderRow(config: config, onEdit: {
                            editingProvider = config
                        }, onDelete: {
                            container.removeProvider(config.providerId)
                        })
                    }
                }
                .scrollContentBackground(.hidden)
            }

            Divider()

            HStack {
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Provider", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(12)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            ProviderFormSheet(container: container) {
                showingAddSheet = false
            }
        }
        .sheet(item: $editingProvider) { config in
            ProviderFormSheet(container: container, existing: config) {
                editingProvider = nil
            }
        }
    }

    private var sortedProviders: [DependencyContainer.ProviderConfig] {
        container.configuredProviders.values
            .sorted { lhs, rhs in
                if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
                return lhs.providerId < rhs.providerId
            }
    }
}

struct ProviderRow: View {
    let config: DependencyContainer.ProviderConfig
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(config.isDefault ? AnvilColor.accentGreen : Color.secondary)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(config.providerId)
                        .foregroundStyle(.primary)
                        .fontWeight(config.isDefault ? .semibold : .regular)
                    if config.isDefault {
                        Text("Default")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(AnvilColor.accentGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentGreen.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(config.providerType.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(AnvilColor.accentRed)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

struct ProviderFormSheet: View {
    let container: DependencyContainer
    var existing: DependencyContainer.ProviderConfig?
    let onDismiss: () -> Void

    @State private var providerId: String = ""
    @State private var providerType: String = "anthropic"
    @State private var apiKey: String = ""
    @State private var baseURL: String = ""
    @State private var commandArgs: String = ""
    @State private var isDefault: Bool = false
    @State private var connectionTestResult: String?

    private let providerTypes = ["claude-cli", "anthropic", "openai", "ollama", "zed-acp", "codex-acp"]

    private let defaultURLs: [String: String] = [
        "claude-cli": "",
        "anthropic": "https://api.anthropic.com",
        "openai": "https://api.openai.com/v1",
        "ollama": "http://localhost:11434",
        "zed-acp": "npx",
        "codex-acp": "codex",
    ]

    var isEditing: Bool { existing != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Provider" : "Add Provider")
                .font(.headline)
                .padding(.top, 16)

            Form {
                if !isEditing {
                    TextField("Provider Name", text: $providerId)
                }

                Picker("Type", selection: $providerType) {
                    ForEach(providerTypes, id: \.self) { type in
                        Text(providerTypeLabel(type)).tag(type)
                    }
                }
                .onChange(of: providerType) { _, newType in
                    if baseURL.isEmpty || defaultURLs.values.contains(baseURL) {
                        baseURL = defaultURLs[newType] ?? ""
                    }
                }

                if providerType == "claude-cli" {
                    HStack {
                        Text("CLI Path")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(detectedCLIPath)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    Text("Uses your existing Claude Code CLI authentication. No API key needed.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else if providerType == "zed-acp" || providerType == "codex-acp" {
                    TextField("Command", text: $baseURL)
                    TextField("Command Args (space-separated)", text: $commandArgs)
                    Text("ACP command-based provider. Use this for external agent protocols.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    if providerType != "ollama" {
                        SecureField("API Key", text: $apiKey)
                    }

                    TextField("Base URL", text: $baseURL)
                }

                Toggle("Set as Default", isOn: $isDefault)

                if let result = connectionTestResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("valid") ? AnvilColor.accentGreen : AnvilColor.accentRed)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Test Connection") {
                    testConnection()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Cancel") {
                    onDismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save" : "Add") {
                    save()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(providerId.isEmpty && !isEditing)
            }
            .padding(16)
        }
        .frame(width: 420, height: 360)
        .onAppear {
            if let existing {
                providerId = existing.providerId
                providerType = existing.providerType
                apiKey = existing.apiKey ?? ""
                baseURL = existing.baseURL ?? defaultURLs[existing.providerType] ?? ""
                commandArgs = existing.commandArgs ?? ""
                isDefault = existing.isDefault
            } else {
                baseURL = defaultURLs["anthropic"] ?? ""
            }
        }
    }

    private var detectedCLIPath: String {
        let paths = [
            "\(NSHomeDirectory())/.local/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        for path in paths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return "Not found"
    }

    private func providerTypeLabel(_ type: String) -> String {
        switch type {
        case "claude-cli": return "Claude CLI (Recommended)"
        case "anthropic": return "Anthropic"
        case "openai": return "OpenAI"
        case "ollama": return "Ollama"
        case "zed-acp": return "ACP Agent Command"
        case "codex-acp": return "Codex ACP"
        default: return type.capitalized
        }
    }

    private func testConnection() {
        if providerType == "claude-cli" {
            let cliPath = detectedCLIPath
            guard cliPath != "Not found" else {
                connectionTestResult = "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: cliPath)
            process.arguments = ["--version"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if process.terminationStatus == 0 {
                    connectionTestResult = "Connection valid \u{2014} Claude CLI \(version)"
                } else {
                    connectionTestResult = "Claude CLI found but returned an error"
                }
            } catch {
                connectionTestResult = "Failed to run Claude CLI: \(error.localizedDescription)"
            }
        } else if providerType == "ollama" {
            connectionTestResult = !baseURL.isEmpty ? "Connection looks valid" : "Base URL required"
        } else if providerType == "zed-acp" {
            let command = baseURL.isEmpty ? "npx" : baseURL
            let args = splitArgs(commandArgs, fallback: ["@agentclientprotocol/claude-agent-acp", "--help"])
            let available = ZedACPProvider.isAvailable(command: command, args: args)
            connectionTestResult = available ? "Connection valid — ACP command reachable" : "ACP command not available"
        } else if providerType == "codex-acp" {
            let command = baseURL.isEmpty ? "codex" : baseURL
            let args = splitArgs(commandArgs, fallback: ["acp", "--help"])
            let available = CodexACPProvider.isAvailable(command: command, args: args)
            connectionTestResult = available ? "Connection valid — Codex ACP reachable" : "Codex ACP command not available"
        } else {
            connectionTestResult = !apiKey.isEmpty && !baseURL.isEmpty ? "Credentials look valid" : "API key and base URL required"
        }
    }

    private func save() {
        let id = isEditing ? (existing?.providerId ?? providerId) : providerId
        let config = DependencyContainer.ProviderConfig(
            providerId: id,
            providerType: providerType,
            apiKey: apiKey.isEmpty ? nil : apiKey,
            baseURL: baseURL.isEmpty ? nil : baseURL,
            commandArgs: commandArgs.isEmpty ? nil : commandArgs,
            isDefault: isDefault
        )
        container.configureProvider(config)
    }

    private func splitArgs(_ raw: String, fallback: [String]) -> [String] {
        let pieces = raw
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { !$0.isEmpty }
        return pieces.isEmpty ? fallback : pieces
    }
}

// MARK: - Appearance Tab

struct AppearanceSettingsView: View {
    @StateObject private var settings = AnvilSettings.shared

    var body: some View {
        Form {
            Section("Editor") {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(Int(settings.codeFontSize)) px")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.codeFontSize, in: 10...20, step: 1)

                Toggle("Show Line Numbers", isOn: $settings.showLineNumbers)
                Toggle("Show Minimap", isOn: $settings.showMinimap)
            }

            Section("Layout") {
                HStack {
                    Text("Sidebar Width")
                    Spacer()
                    Text("\(Int(settings.sidebarWidth)) px")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $settings.sidebarWidth, in: 200...400, step: 10)
            }
        }
        .formStyle(.grouped)
    }
}


// MARK: - Keybindings Tab

struct KeybindingSettingsView: View {
    @State private var searchText: String = ""

    private let contextOrder: [KeybindingContext] = [.global, .list, .review, .agent]

    private var filteredBindings: [Keybinding] {
        if searchText.isEmpty { return AnvilKeybindings.all }
        let query = searchText.lowercased()
        return AnvilKeybindings.all.filter {
            $0.label.lowercased().contains(query) ||
            $0.action.lowercased().contains(query) ||
            $0.context.rawValue.lowercased().contains(query)
        }
    }

    private func bindings(for context: KeybindingContext) -> [Keybinding] {
        filteredBindings.filter { $0.context == context }
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search keybindings...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            List {
                ForEach(contextOrder, id: \.rawValue) { context in
                    let group = bindings(for: context)
                    if !group.isEmpty {
                        Section(context.rawValue.capitalized) {
                            ForEach(group) { binding in
                                KeybindingRow(binding: binding)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)

            Divider()

            HStack {
                Spacer()
                Button("Reset to Defaults") {
                }
                .disabled(true)
                .help("Reset all keybindings to defaults")
                .buttonStyle(.bordered)
                .padding(12)
            }
        }
    }
}

struct KeybindingRow: View {
    let binding: Keybinding

    var body: some View {
        HStack {
            Text(binding.label)
                .foregroundStyle(.primary)

            Spacer()

            Text(keyComboString)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var keyComboString: String {
        var parts: [String] = []
        if binding.modifiers.contains(.command) { parts.append("\u{2318}") }
        if binding.modifiers.contains(.shift) { parts.append("\u{21E7}") }
        if binding.modifiers.contains(.option) { parts.append("\u{2325}") }
        if binding.modifiers.contains(.control) { parts.append("\u{2303}") }
        parts.append(keyLabel(binding.key))
        return parts.joined()
    }

    private func keyLabel(_ key: KeyEquivalent) -> String {
        switch key {
        case .return: return "\u{21A9}"
        case .tab: return "\u{21E5}"
        case .space: return "\u{2423}"
        case .escape: return "\u{238B}"
        case .delete: return "\u{232B}"
        case .upArrow: return "\u{2191}"
        case .downArrow: return "\u{2193}"
        case .leftArrow: return "\u{2190}"
        case .rightArrow: return "\u{2192}"
        default: return String(key.character).uppercased()
        }
    }
}

// MARK: - Advanced Tab

struct AdvancedSettingsView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Form {
            Section("Worktrees") {
                HStack {
                    Text(appState.defaultWorktreePath.isEmpty ? "Default (sibling directory)" : appState.defaultWorktreePath)
                        .foregroundStyle(appState.defaultWorktreePath.isEmpty ? .tertiary : .primary)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer()
                    Button("Choose...") {
                        chooseWorktreePath()
                    }
                }
                .help("Directory where agent worktrees are created. Leave empty to use a sibling directory of the project.")
            }

            Section("Agent Automation") {
                Toggle("Auto-create draft PR on session completion", isOn: $appState.isAutoPREnabled)
                    .help("Automatically creates a draft GitHub PR when an agent session completes with file changes in an isolated worktree.")

                Toggle("Auto-scan sessions for memories", isOn: $appState.isMemoryScanEnabled)
                    .help("Automatically scans completed agent sessions to extract reusable memories and project context.")
            }
        }
        .formStyle(.grouped)
    }

    private func chooseWorktreePath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose default worktree directory"
        if panel.runModal() == .OK, let url = panel.url {
            appState.defaultWorktreePath = url.path
        }
    }
}

// MARK: - Identifiable conformance for sheet(item:)

extension DependencyContainer.ProviderConfig: Identifiable {
    public var id: String { providerId }
}
