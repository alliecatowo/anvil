import Foundation

public struct HTTPRequest: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String?
    public let method: HTTPMethod
    public let url: String
    public let headers: [String: String]
    public let body: String?
    public let queryParameters: [String: String]

    public init(id: String = UUID().uuidString, name: String? = nil, method: HTTPMethod = .get, url: String, headers: [String: String] = [:], body: String? = nil, queryParameters: [String: String] = [:]) {
        self.id = id
        self.name = name
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.queryParameters = queryParameters
    }
}

public enum HTTPMethod: String, Sendable, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
}

public struct HTTPResponse: Sendable, Codable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: String?
    public let durationMs: Double

    public init(statusCode: Int, headers: [String: String] = [:], body: String? = nil, durationMs: Double = 0) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.durationMs = durationMs
    }
}
