import Foundation

/// File-based storage for markdown documents, configuration, etc.
public actor FileStore {
    private let basePath: String

    public init(basePath: String = "~/.anvil") {
        self.basePath = basePath
    }

    public func read(path: String) async throws -> Data {
        let url = URL(fileURLWithPath: resolvePath(path))
        return try Data(contentsOf: url)
    }

    public func write(path: String, data: Data) async throws {
        let url = URL(fileURLWithPath: resolvePath(path))
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url)
    }

    public func exists(path: String) -> Bool {
        FileManager.default.fileExists(atPath: resolvePath(path))
    }

    public func delete(path: String) async throws {
        try FileManager.default.removeItem(atPath: resolvePath(path))
    }

    private func resolvePath(_ path: String) -> String {
        if path.hasPrefix("/") { return path }
        return "\(basePath)/\(path)"
    }
}
