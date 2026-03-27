import Foundation

public protocol DesignPort: AnvilProviderDefinition {
    func files(projectId: String) async throws -> [DesignFile]
    func file(fileId: String) async throws -> DesignFile
    func tokens(fileId: String) async throws -> [DesignToken]
    func exportAssets(fileId: String, format: String) async throws -> Data
    func syncTokens(fileId: String, outputPath: String) async throws -> [DesignToken]
}
