import Foundation
import AnvilDomain
import AnvilApplication
import AnvilACP
import AnvilGit

/// Central dependency container that wires all layers together.
/// ViewModels access ports and services through this container.
@MainActor
public class DependencyContainer: ObservableObject {
    // MARK: - Services

    public let eventBus = EventBus.shared
    public let acpRouter = ACPRouter()
    public let pluginManager = PluginManager()
    public let projectManager = ProjectManager()
    public let notificationAggregator = NotificationAggregator()
    public let searchIndexer = SearchIndexer()
    public let worktreeOrchestrator = WorktreeOrchestrator()

    // MARK: - Git Adapter

    private var gitAdapter: GitSourceControlAdapter?

    public func getOrCreateGitAdapter() -> GitSourceControlAdapter? {
        guard let path = currentProjectPath else { return nil }
        if let adapter = gitAdapter { return adapter }
        let adapter = GitSourceControlAdapter(workingDirectory: path)
        gitAdapter = adapter
        return adapter
    }

    // MARK: - ACP Client

    private var acpClient: ACPClient?

    public func getOrCreateACPClient() async -> ACPClient {
        if let client = acpClient { return client }
        let client = ACPClient()
        for (_, config) in configuredProviders {
            switch config.providerType {
            case "claude-cli":
                let provider = ClaudeCLIProvider(cliPath: config.baseURL ?? "")
                await client.registerProvider(provider)
                if config.isDefault { await client.setDefaultProvider(provider.providerId) }
            case "claude-process":
                let cliPath = config.baseURL ?? ""
                await client.registerProcessProvider(id: config.providerId, path: cliPath)
                if config.isDefault { await client.setDefaultProvider("claude-process") }
            case "anthropic":
                if let apiKey = config.apiKey {
                    let provider = AnthropicProvider(apiKey: apiKey)
                    await client.registerProvider(provider)
                    if config.isDefault { await client.setDefaultProvider(provider.providerId) }
                }
            case "openai":
                if let apiKey = config.apiKey {
                    let provider = OpenAIProvider(apiKey: apiKey)
                    await client.registerProvider(provider)
                    if config.isDefault { await client.setDefaultProvider(provider.providerId) }
                }
            case "ollama":
                let provider = OllamaProvider(baseURL: config.baseURL ?? "http://localhost:11434")
                await client.registerProvider(provider)
                if config.isDefault { await client.setDefaultProvider(provider.providerId) }
            default:
                break
            }
        }

        // Auto-register Claude CLI if no providers are configured and the binary exists
        if configuredProviders.isEmpty && ClaudeCLIProvider.isAvailable() {
            let provider = ClaudeCLIProvider()
            await client.registerProvider(provider)
            await client.setDefaultProvider(provider.providerId)
        }

        acpClient = client
        return client
    }

    // MARK: - File System

    public let fileSystemService = FileSystemService()

    // MARK: - Configuration

    @Published public var currentProjectPath: String?
    @Published public var configuredProviders: [String: ProviderConfig] = [:]

    // MARK: - Ports (resolved lazily from configuration)

    private var _sourceControlPort: (any SourceControlPort)?
    private var _acpPort: (any ACPPort)?

    public var sourceControlPort: (any SourceControlPort)? {
        _sourceControlPort
    }

    public var acpPort: (any ACPPort)? {
        _acpPort
    }

    // MARK: - Init

    public init() {
        loadSavedConfiguration()
    }

    // MARK: - Configuration

    public struct ProviderConfig: Codable, Sendable {
        public let providerId: String
        public let providerType: String // "claude-cli", "anthropic", "openai", "ollama"
        public var apiKey: String?
        public var baseURL: String?
        public var isDefault: Bool

        public init(providerId: String, providerType: String, apiKey: String? = nil, baseURL: String? = nil, isDefault: Bool = false) {
            self.providerId = providerId
            self.providerType = providerType
            self.apiKey = apiKey
            self.baseURL = baseURL
            self.isDefault = isDefault
        }
    }

    // MARK: - Project Management

    public func openProject(at path: String) async {
        currentProjectPath = path

        // Reset the cached adapter so getOrCreateGitAdapter() creates one for the new path
        gitAdapter = nil

        await projectManager.addProject(.init(name: URL(fileURLWithPath: path).lastPathComponent, path: path))
        await projectManager.setCurrentProject(path)
    }

    // MARK: - Provider Configuration

    public func configureProvider(_ config: ProviderConfig) {
        configuredProviders[config.providerId] = config
        saveConfiguration()
    }

    public func removeProvider(_ providerId: String) {
        configuredProviders.removeValue(forKey: providerId)
        saveConfiguration()
    }

    // MARK: - Use Cases

    public func makeStartAgentSessionUseCase() -> StartAgentSessionUseCase {
        StartAgentSessionUseCase()
    }

    public func makeAutoCommitUseCase() -> AutoCommitUseCase {
        AutoCommitUseCase()
    }

    public func makeSubmitReviewUseCase() -> SubmitReviewUseCase {
        SubmitReviewUseCase()
    }

    public func makeAIReviewUseCase() -> AIReviewUseCase {
        AIReviewUseCase()
    }

    public func makeCreateProjectUseCase() -> CreateProjectUseCase {
        CreateProjectUseCase()
    }

    // MARK: - Persistence

    private let configURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".anvil/config/providers.json")

    private func loadSavedConfiguration() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        guard let data = try? Data(contentsOf: configURL),
              let configs = try? JSONDecoder().decode([String: ProviderConfig].self, from: data) else { return }
        configuredProviders = configs
    }

    private func saveConfiguration() {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(configuredProviders) {
            try? data.write(to: configURL)
        }
    }
}

// MARK: - File System Service

/// Reads directory trees and file contents from disk.
@MainActor
public final class FileSystemService {

    public struct FileNode: Identifiable, Sendable {
        public let id: String
        public let name: String
        public let path: String
        public let isDirectory: Bool
        public var children: [FileNode]?

        public init(id: String, name: String, path: String, isDirectory: Bool, children: [FileNode]? = nil) {
            self.id = id
            self.name = name
            self.path = path
            self.isDirectory = isDirectory
            self.children = children
        }
    }

    private static let ignoredNames: Set<String> = [
        ".git", ".build", ".swiftpm", "node_modules", ".DS_Store",
        "DerivedData", "Pods", ".hg", ".svn", "xcuserdata",
    ]

    public init() {}

    /// Recursively read a directory tree, skipping common noise directories.
    public func readTree(at path: String, maxDepth: Int = 3) -> [FileNode] {
        readTreeRecursive(at: path, currentDepth: 0, maxDepth: maxDepth)
    }

    /// Read the full text contents of a file.
    public func readFile(at path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func readTreeRecursive(at path: String, currentDepth: Int, maxDepth: Int) -> [FileNode] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else { return [] }

        var nodes: [FileNode] = []

        let sorted = entries.sorted { lhs, rhs in
            let lhsIsDir = self.isDirectory(atPath: (path as NSString).appendingPathComponent(lhs))
            let rhsIsDir = self.isDirectory(atPath: (path as NSString).appendingPathComponent(rhs))
            if lhsIsDir != rhsIsDir { return lhsIsDir }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        for entry in sorted {
            guard !Self.ignoredNames.contains(entry) else { continue }
            guard !entry.hasPrefix(".") || entry == ".env.example" else { continue }

            let fullPath = (path as NSString).appendingPathComponent(entry)
            let isDir = isDirectory(atPath: fullPath)

            if isDir {
                let children: [FileNode]?
                if currentDepth < maxDepth {
                    children = readTreeRecursive(at: fullPath, currentDepth: currentDepth + 1, maxDepth: maxDepth)
                } else {
                    children = nil
                }
                nodes.append(FileNode(id: fullPath, name: entry, path: fullPath, isDirectory: true, children: children))
            } else {
                nodes.append(FileNode(id: fullPath, name: entry, path: fullPath, isDirectory: false))
            }
        }

        return nodes
    }

    private func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return isDir.boolValue
    }
}
