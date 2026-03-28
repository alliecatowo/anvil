import SwiftUI

// MARK: - Models

enum PluginCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case languages = "Languages"
    case themes = "Themes"
    case ai = "AI"
    case git = "Git"
    case testing = "Testing"
    case deployment = "Deployment"
    case database = "Database"
    case formatting = "Formatting"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2"
        case .languages: "chevron.left.forwardslash.chevron.right"
        case .themes: "paintpalette"
        case .ai: "cpu"
        case .git: "arrow.triangle.branch"
        case .testing: "testtube.2"
        case .deployment: "shippingbox"
        case .database: "cylinder"
        case .formatting: "text.alignleft"
        }
    }
}

enum PluginSortOrder: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case recent = "Recent"
    case nameAsc = "Name A-Z"
    case nameDesc = "Name Z-A"

    var id: String { rawValue }
}

struct MarketplacePlugin: Identifiable {
    let id: String
    let name: String
    let pluginDescription: String
    let author: String
    let version: String
    let category: PluginCategory
    let icon: String
    let downloadCount: Int
    let rating: Double
    var isInstalled: Bool
    var isEnabled: Bool

    var downloadCountFormatted: String {
        if downloadCount >= 1_000_000 {
            return String(format: "%.1fM", Double(downloadCount) / 1_000_000)
        } else if downloadCount >= 1_000 {
            return String(format: "%.1fK", Double(downloadCount) / 1_000)
        }
        return "\(downloadCount)"
    }
}

// MARK: - ViewModel

@MainActor
class PluginMarketplaceViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedCategory: PluginCategory = .all
    @Published var sortOrder: PluginSortOrder = .popular
    @Published var selectedPluginId: String?
    @Published var viewMode: ExtensionsViewMode = .browse
    @Published var plugins: [MarketplacePlugin] = []

    enum ExtensionsViewMode {
        case browse
        case installed
        case detail(String)
    }

    var selectedPlugin: MarketplacePlugin? {
        guard let id = selectedPluginId else { return nil }
        return plugins.first { $0.id == id }
    }

    var filteredPlugins: [MarketplacePlugin] {
        var result = plugins

        if selectedCategory != .all {
            result = result.filter { $0.category == selectedCategory }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.pluginDescription.lowercased().contains(query) ||
                $0.author.lowercased().contains(query)
            }
        }

        switch sortOrder {
        case .popular:
            result.sort { $0.downloadCount > $1.downloadCount }
        case .recent:
            result.sort { $0.id > $1.id }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }

        return result
    }

    var installedPlugins: [MarketplacePlugin] {
        plugins.filter { $0.isInstalled }
    }

    var installedCount: Int {
        installedPlugins.count
    }

    init() {
        plugins = []
    }

    /// Load built-in plugin catalog for previews and initial state.
    func loadBuiltInPlugins() {
        plugins = Self.samplePlugins()
    }

    // MARK: - Actions

    func selectPlugin(_ id: String) {
        selectedPluginId = id
        viewMode = .detail(id)
    }

    func installPlugin(_ id: String) {
        guard let index = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[index].isInstalled = true
        plugins[index].isEnabled = true
    }

    func uninstallPlugin(_ id: String) {
        guard let index = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[index].isInstalled = false
        plugins[index].isEnabled = false
    }

    func togglePlugin(_ id: String) {
        guard let index = plugins.firstIndex(where: { $0.id == id }) else { return }
        plugins[index].isEnabled.toggle()
    }

    // MARK: - Sample Data

    static func samplePlugins() -> [MarketplacePlugin] {
        [
            MarketplacePlugin(
                id: "anvil.python", name: "Python", pluginDescription: "Rich Python language support with IntelliSense, linting, debugging, and Jupyter notebooks.",
                author: "Anvil", version: "2024.3.1", category: .languages, icon: "chevron.left.forwardslash.chevron.right",
                downloadCount: 892_000, rating: 4.8, isInstalled: true, isEnabled: true
            ),
            MarketplacePlugin(
                id: "anvil.swift-lang", name: "Swift Language", pluginDescription: "Swift language support with SourceKit-LSP integration, code completion, and diagnostics.",
                author: "Anvil", version: "1.12.0", category: .languages, icon: "swift",
                downloadCount: 645_000, rating: 4.7, isInstalled: true, isEnabled: true
            ),
            MarketplacePlugin(
                id: "anvil.github-copilot", name: "GitHub Copilot", pluginDescription: "AI-powered code completion and suggestions. Supports multiple languages and frameworks.",
                author: "GitHub", version: "1.5.0", category: .ai, icon: "cpu",
                downloadCount: 1_200_000, rating: 4.6, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.docker", name: "Docker", pluginDescription: "Build, manage, and deploy containerized applications from Anvil.",
                author: "Microsoft", version: "1.29.0", category: .deployment, icon: "shippingbox",
                downloadCount: 534_000, rating: 4.5, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.prettier", name: "Prettier", pluginDescription: "Opinionated code formatter. Supports JavaScript, TypeScript, CSS, HTML, JSON, and more.",
                author: "Prettier", version: "10.4.0", category: .formatting, icon: "text.alignleft",
                downloadCount: 780_000, rating: 4.7, isInstalled: true, isEnabled: true
            ),
            MarketplacePlugin(
                id: "anvil.gitlens", name: "GitLens", pluginDescription: "Supercharge Git — visualize code authorship, navigate history, and compare branches.",
                author: "GitKraken", version: "15.1.0", category: .git, icon: "arrow.triangle.branch",
                downloadCount: 670_000, rating: 4.8, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.jest-runner", name: "Jest Runner", pluginDescription: "Run and debug Jest tests from the editor. Supports watch mode and coverage display.",
                author: "Community", version: "3.2.1", category: .testing, icon: "testtube.2",
                downloadCount: 320_000, rating: 4.4, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.postgres-explorer", name: "Postgres Explorer", pluginDescription: "Browse PostgreSQL databases, run queries, and manage schemas directly in Anvil.",
                author: "Community", version: "2.0.3", category: .database, icon: "cylinder",
                downloadCount: 189_000, rating: 4.3, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.tailwind", name: "Tailwind CSS IntelliSense", pluginDescription: "Autocomplete, syntax highlighting, and linting for Tailwind CSS.",
                author: "Tailwind Labs", version: "0.12.0", category: .languages, icon: "paintpalette",
                downloadCount: 560_000, rating: 4.6, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.claude-agent", name: "Claude Agent", pluginDescription: "Deep integration with Claude for code review, refactoring, and autonomous coding tasks.",
                author: "Anthropic", version: "1.0.0", category: .ai, icon: "cpu",
                downloadCount: 420_000, rating: 4.9, isInstalled: true, isEnabled: true
            ),
            MarketplacePlugin(
                id: "anvil.eslint", name: "ESLint", pluginDescription: "Integrates ESLint into Anvil. Find and fix problems in your JavaScript code.",
                author: "Community", version: "3.0.5", category: .formatting, icon: "exclamationmark.triangle",
                downloadCount: 710_000, rating: 4.5, isInstalled: false, isEnabled: false
            ),
            MarketplacePlugin(
                id: "anvil.vercel-deploy", name: "Vercel Deploy", pluginDescription: "Deploy to Vercel directly from Anvil. Preview deployments, manage domains, view logs.",
                author: "Vercel", version: "2.1.0", category: .deployment, icon: "arrow.up.circle",
                downloadCount: 245_000, rating: 4.4, isInstalled: false, isEnabled: false
            ),
        ]
    }
}
