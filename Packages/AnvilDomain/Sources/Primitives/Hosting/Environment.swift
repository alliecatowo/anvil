import Foundation

public struct HostingEnvironment: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let branch: String?
    public let url: String?
    public let isProduction: Bool

    public init(id: String = UUID().uuidString, name: String, branch: String? = nil, url: String? = nil, isProduction: Bool = false) {
        self.id = id
        self.name = name
        self.branch = branch
        self.url = url
        self.isProduction = isProduction
    }
}
