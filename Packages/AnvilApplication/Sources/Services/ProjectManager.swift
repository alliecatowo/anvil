import Foundation

// MARK: - Project Model

public struct Project: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var description: String
    public var repoPaths: [String]
    public let createdAt: Date
    public var lastOpenedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        repoPaths: [String] = [],
        createdAt: Date = .now,
        lastOpenedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.repoPaths = repoPaths
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
    }

    /// Convenience: primary repo path (first in the list).
    public var primaryRepoPath: String? {
        repoPaths.first
    }
}

// MARK: - ProjectManager

public actor ProjectManager {
    private var projects: [String: Project] = [:]
    private var currentProjectId: String?
    private var hasLoaded = false

    private let storageURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".anvil/projects/projects.json")
    }()

    public init() {}

    private func loadIfNeeded() {
        guard !hasLoaded else { return }
        hasLoaded = true
        loadFromDisk()
    }

    // MARK: - CRUD

    public func addProject(_ project: Project) {
        loadIfNeeded()
        projects[project.id] = project
        saveToDisk()
    }

    public func updateProject(_ project: Project) {
        loadIfNeeded()
        projects[project.id] = project
        saveToDisk()
    }

    public func removeProject(_ id: String) {
        loadIfNeeded()
        projects.removeValue(forKey: id)
        if currentProjectId == id { currentProjectId = nil }
        saveToDisk()
    }

    public func setCurrentProject(_ id: String) {
        loadIfNeeded()
        currentProjectId = id
        if var project = projects[id] {
            project.lastOpenedAt = .now
            projects[id] = project
            saveToDisk()
        }
    }

    public func currentProject() -> Project? {
        loadIfNeeded()
        guard let id = currentProjectId else { return nil }
        return projects[id]
    }

    public func getCurrentProjectId() -> String? {
        loadIfNeeded()
        return currentProjectId
    }

    public func project(byId id: String) -> Project? {
        loadIfNeeded()
        return projects[id]
    }

    public func allProjects() -> [Project] {
        loadIfNeeded()
        return Array(projects.values).sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    /// Find a project that contains the given repo path.
    public func project(containingRepo path: String) -> Project? {
        loadIfNeeded()
        return projects.values.first { $0.repoPaths.contains(path) }
    }

    // MARK: - Persistence

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        guard let data = try? Data(contentsOf: storageURL),
              let stored = try? JSONDecoder().decode(StoredProjects.self, from: data) else { return }
        for project in stored.projects {
            projects[project.id] = project
        }
        currentProjectId = stored.currentProjectId
    }

    private func saveToDisk() {
        let dir = storageURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stored = StoredProjects(
            projects: Array(projects.values),
            currentProjectId: currentProjectId
        )
        if let data = try? JSONEncoder().encode(stored) {
            try? data.write(to: storageURL, options: .atomic)
        }
    }
}

// MARK: - Storage Format

private struct StoredProjects: Codable {
    let projects: [Project]
    let currentProjectId: String?
}
