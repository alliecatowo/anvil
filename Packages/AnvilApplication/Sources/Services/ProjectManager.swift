import Foundation

public actor ProjectManager {
    public struct Project: Sendable {
        public let id: String
        public let name: String
        public let path: String
        public let createdAt: Date
        public var lastOpenedAt: Date

        public init(id: String = UUID().uuidString, name: String, path: String, createdAt: Date = .now, lastOpenedAt: Date = .now) {
            self.id = id
            self.name = name
            self.path = path
            self.createdAt = createdAt
            self.lastOpenedAt = lastOpenedAt
        }
    }

    private var projects: [String: Project] = [:]
    private var currentProjectId: String?

    public init() {}

    public func addProject(_ project: Project) {
        projects[project.id] = project
    }

    public func setCurrentProject(_ id: String) {
        currentProjectId = id
        if var project = projects[id] {
            project.lastOpenedAt = .now
            projects[id] = project
        }
    }

    public func currentProject() -> Project? {
        guard let id = currentProjectId else { return nil }
        return projects[id]
    }

    public func allProjects() -> [Project] {
        Array(projects.values).sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }
}
