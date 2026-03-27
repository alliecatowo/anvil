import Foundation
import SwiftUI

// MARK: - Models

public struct DetectedTool: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public var path: String?
    public var version: String?
    public var isInstalled: Bool
    public let isRequired: Bool

    public init(id: String, name: String, icon: String, path: String? = nil, version: String? = nil, isInstalled: Bool = false, isRequired: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.path = path
        self.version = version
        self.isInstalled = isInstalled
        self.isRequired = isRequired
    }
}

public enum ACPProviderOption: String, CaseIterable, Identifiable, Sendable {
    case claudeCLI = "claude-cli"
    case anthropic = "anthropic"
    case openai = "openai"
    case ollama = "ollama"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeCLI: "Claude CLI"
        case .anthropic: "Anthropic API"
        case .openai: "OpenAI"
        case .ollama: "Ollama"
        }
    }

    public var subtitle: String {
        switch self {
        case .claudeCLI: "Use your existing Claude connection. No API key needed."
        case .anthropic: "Direct API access. Requires API key."
        case .openai: "Use GPT models. Requires API key."
        case .ollama: "Local models. Free, private, no internet."
        }
    }

    public var icon: String {
        switch self {
        case .claudeCLI: "terminal"
        case .anthropic: "bolt.horizontal"
        case .openai: "brain"
        case .ollama: "desktopcomputer"
        }
    }

    public var needsAPIKey: Bool {
        self == .anthropic || self == .openai
    }

    public var needsURL: Bool {
        self == .ollama
    }
}

public enum ProjectSetupOption: String, Sendable {
    case openExisting
    case cloneRepository
    case startFresh
}

public enum SetupStep: Int, CaseIterable, Sendable {
    case welcome = 0
    case detectEnvironment = 1
    case configureACP = 2
    case openProject = 3
    case ready = 4
}

// MARK: - ViewModel

@MainActor
public final class SetupWizardViewModel: ObservableObject {
    // MARK: - Navigation

    @Published public var currentStep: SetupStep = .welcome

    // MARK: - Environment Detection

    @Published public var detectedTools: [DetectedTool] = [
        DetectedTool(id: "claude", name: "Claude CLI", icon: "terminal", isRequired: true),
        DetectedTool(id: "git", name: "Git", icon: "arrow.triangle.branch", isRequired: true),
        DetectedTool(id: "docker", name: "Docker", icon: "shippingbox", isRequired: false),
        DetectedTool(id: "node", name: "Node.js", icon: "server.rack", isRequired: false),
    ]
    @Published public var isScanning: Bool = false

    // MARK: - ACP Configuration

    @Published public var selectedProvider: ACPProviderOption = .claudeCLI
    @Published public var apiKey: String = ""
    @Published public var ollamaURL: String = "http://localhost:11434"
    @Published public var connectionTestResult: ConnectionTestState = .idle

    public enum ConnectionTestState: Sendable {
        case idle, testing, success, failure(String)
    }

    // MARK: - Project

    @Published public var projectSetupOption: ProjectSetupOption = .openExisting
    @Published public var cloneURL: String = ""
    @Published public var newProjectName: String = ""
    @Published public var selectedProjectPath: String?

    // MARK: - First Launch

    private static let firstLaunchKey = "anvil.hasCompletedSetup"

    public static var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: firstLaunchKey)
    }

    public static func markSetupComplete() {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)
    }

    // MARK: - Computed

    public var environmentSummary: String {
        let installed = detectedTools.filter(\.isInstalled).count
        let total = detectedTools.count
        let missingRequired = detectedTools.filter { $0.isRequired && !$0.isInstalled }
        if missingRequired.isEmpty {
            return "Your environment looks great — \(installed)/\(total) tools detected."
        } else {
            let names = missingRequired.map(\.name).joined(separator: ", ")
            return "Missing required tools: \(names)"
        }
    }

    public var canProceedFromACP: Bool {
        switch selectedProvider {
        case .claudeCLI:
            return detectedTools.first(where: { $0.id == "claude" })?.isInstalled == true
        case .anthropic, .openai:
            return !apiKey.isEmpty
        case .ollama:
            return !ollamaURL.isEmpty
        }
    }

    public var canProceedFromProject: Bool {
        switch projectSetupOption {
        case .openExisting:
            return selectedProjectPath != nil
        case .cloneRepository:
            return !cloneURL.isEmpty
        case .startFresh:
            return !newProjectName.isEmpty
        }
    }

    // MARK: - Init

    public init() {}

    // MARK: - Navigation

    public func goNext() {
        guard let next = SetupStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    public func goBack() {
        guard let prev = SetupStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    // MARK: - Environment Detection

    public func scanEnvironment() async {
        isScanning = true
        defer { isScanning = false }

        await withTaskGroup(of: (String, String?, String?, Bool).self) { group in
            let toolSpecs: [(id: String, binary: String, versionFlag: String)] = [
                ("claude", "claude", "--version"),
                ("git", "git", "--version"),
                ("docker", "docker", "--version"),
                ("node", "node", "--version"),
            ]

            for spec in toolSpecs {
                group.addTask { @Sendable in
                    let path = await self.findBinary(spec.binary)
                    var version: String?
                    if path != nil {
                        version = await self.getVersion(spec.binary, flag: spec.versionFlag)
                    }
                    return (spec.id, path, version, path != nil)
                }
            }

            for await (id, path, version, installed) in group {
                if let idx = detectedTools.firstIndex(where: { $0.id == id }) {
                    detectedTools[idx].path = path
                    detectedTools[idx].version = version
                    detectedTools[idx].isInstalled = installed
                }
            }
        }

        // Auto-select Claude CLI if detected
        if detectedTools.first(where: { $0.id == "claude" })?.isInstalled == true {
            selectedProvider = .claudeCLI
        }
    }

    private func findBinary(_ name: String) async -> String? {
        await runCommand("/usr/bin/which", arguments: [name])
    }

    private func getVersion(_ name: String, flag: String) async -> String? {
        guard let output = await runCommand("/usr/bin/env", arguments: [name, flag]) else { return nil }
        // Clean up version strings - take first line, trim whitespace
        let firstLine = output.components(separatedBy: .newlines).first ?? output
        return firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runCommand(_ path: String, arguments: [String]) async -> String? {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: output?.isEmpty == true ? nil : output)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Connection Test

    public func testConnection() async {
        connectionTestResult = .testing

        switch selectedProvider {
        case .claudeCLI:
            let available = detectedTools.first(where: { $0.id == "claude" })?.isInstalled == true
            connectionTestResult = available ? .success : .failure("Claude CLI not found")
        case .anthropic:
            // Simple validation — real test would hit the API
            connectionTestResult = apiKey.hasPrefix("sk-ant-") ? .success : .failure("API key should start with sk-ant-")
        case .openai:
            connectionTestResult = apiKey.hasPrefix("sk-") ? .success : .failure("API key should start with sk-")
        case .ollama:
            // Try connecting to Ollama
            if let url = URL(string: ollamaURL) {
                let request = URLRequest(url: url, timeoutInterval: 5)
                do {
                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                        connectionTestResult = .success
                    } else {
                        connectionTestResult = .failure("Ollama not responding")
                    }
                } catch {
                    connectionTestResult = .failure("Cannot reach \(ollamaURL)")
                }
            } else {
                connectionTestResult = .failure("Invalid URL")
            }
        }
    }

    // MARK: - Project Setup

    public func openDirectoryPicker() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a project directory"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            selectedProjectPath = url.path
        }
    }

    public func setupProject(container: DependencyContainer) async {
        switch projectSetupOption {
        case .openExisting:
            if let path = selectedProjectPath {
                await container.openProject(at: path)
            }
        case .cloneRepository:
            // Clone into ~/Developer/ by default
            let targetDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer")
                .path
            let repoName = URL(string: cloneURL)?
                .lastPathComponent
                .replacingOccurrences(of: ".git", with: "") ?? "project"
            let fullPath = (targetDir as NSString).appendingPathComponent(repoName)

            _ = await runCommand("/usr/bin/git", arguments: ["clone", cloneURL, fullPath])
            await container.openProject(at: fullPath)
            selectedProjectPath = fullPath
        case .startFresh:
            let targetDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Developer")
                .appendingPathComponent(newProjectName)
            try? FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
            _ = await runCommand("/usr/bin/git", arguments: ["init", targetDir.path])
            await container.openProject(at: targetDir.path)
            selectedProjectPath = targetDir.path
        }
    }

    // MARK: - Provider Config

    public func buildProviderConfig() -> DependencyContainer.ProviderConfig {
        switch selectedProvider {
        case .claudeCLI:
            let path = detectedTools.first(where: { $0.id == "claude" })?.path
            return .init(providerId: "claude-cli", providerType: "claude-cli", baseURL: path, isDefault: true)
        case .anthropic:
            return .init(providerId: "anthropic", providerType: "anthropic", apiKey: apiKey, isDefault: true)
        case .openai:
            return .init(providerId: "openai", providerType: "openai", apiKey: apiKey, isDefault: true)
        case .ollama:
            return .init(providerId: "ollama", providerType: "ollama", baseURL: ollamaURL, isDefault: true)
        }
    }
}
