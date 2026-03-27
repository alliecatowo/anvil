import Foundation

public struct BuildLog: Sendable, Identifiable, Codable {
    public let id: String
    public let deploymentId: String
    public let timestamp: Date
    public let level: BuildLogLevel
    public let message: String

    public init(id: String = UUID().uuidString, deploymentId: String, timestamp: Date = .now, level: BuildLogLevel = .info, message: String) {
        self.id = id
        self.deploymentId = deploymentId
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

public enum BuildLogLevel: String, Sendable, Codable {
    case debug, info, warning, error
}
