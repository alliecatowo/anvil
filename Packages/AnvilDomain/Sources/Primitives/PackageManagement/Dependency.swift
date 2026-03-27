import Foundation

public struct Dependency: Sendable, Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let currentVersion: String
    public let latestVersion: String?
    public let packageManager: PackageManagerType
    public let isDevDependency: Bool

    public init(name: String, currentVersion: String, latestVersion: String? = nil, packageManager: PackageManagerType, isDevDependency: Bool = false) {
        self.name = name
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.packageManager = packageManager
        self.isDevDependency = isDevDependency
    }
}

public enum PackageManagerType: String, Sendable, Codable {
    case npm, yarn, pnpm, pip, cargo, spm, cocoapods, gradle, maven
}
