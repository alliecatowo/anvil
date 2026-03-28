import Foundation

/// Low-level HTTP client for the GitHub REST API.
actor GitHubClient {
    private let baseURL: String
    private let token: String
    private let session: URLSession

    init(token: String, baseURL: String = "https://api.github.com") {
        self.token = token
        self.baseURL = baseURL
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Generic Request

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let data = try await request("GET", path: path, query: query)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(body)

        let data = try await request("POST", path: path, body: bodyData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func patch<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(body)

        let data = try await request("PATCH", path: path, body: bodyData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    func put(_ path: String) async throws {
        _ = try await request("PUT", path: path)
    }

    func patch(_ path: String) async throws {
        _ = try await request("PATCH", path: path)
    }

    /// Execute a GraphQL query/mutation against the GitHub GraphQL API.
    func graphql<T: Decodable>(query: String, variables: [String: String] = [:]) async throws -> T {
        let body: [String: Any] = [
            "query": query,
            "variables": variables
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        // GraphQL uses a different endpoint
        var components = URLComponents(string: "https://api.github.com/graphql")!
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Private

    private func request(_ method: String, path: String, query: [String: String] = [:], body: Data? = nil) async throws -> Data {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GitHubError.apiError(statusCode: httpResponse.statusCode, message: message)
        }

        return data
    }
}

enum GitHubError: Error, Sendable {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case notConfigured
}
