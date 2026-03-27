import Foundation

public struct RequestCollection: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let requests: [HTTPRequest]
    public let variables: [String: String]

    public init(id: String = UUID().uuidString, name: String, requests: [HTTPRequest] = [], variables: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.requests = requests
        self.variables = variables
    }
}
