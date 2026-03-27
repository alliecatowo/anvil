import Foundation

public struct GitRemote: Sendable, Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let fetchURL: String
    public let pushURL: String

    public init(name: String, fetchURL: String, pushURL: String) {
        self.name = name
        self.fetchURL = fetchURL
        self.pushURL = pushURL
    }
}
