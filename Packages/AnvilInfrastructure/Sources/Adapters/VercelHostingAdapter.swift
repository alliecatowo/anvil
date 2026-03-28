import Foundation
import AnvilDomain

/// Vercel hosting adapter implementing HostingPort using the Vercel REST API.
/// Supports deploy, list deployments, get logs, manage env vars.
///
/// Configuration:
///   - `apiToken`: Vercel API token (required)
///   - `teamId`: Optional team ID for team-scoped requests
/// @unchecked Sendable: All stored properties are immutable after init (let bindings + URLSession).
public final class VercelHostingAdapter: HostingPort, @unchecked Sendable {
    public let providerId: String = "vercel"
    public let providerName: String = "Vercel"

    private let apiToken: String
    private let teamId: String?
    private let baseURL = "https://api.vercel.com"
    private let session: URLSession

    public init(apiToken: String, teamId: String? = nil) {
        self.apiToken = apiToken
        self.teamId = teamId
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(apiToken)",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        // GET /v2/user to validate the token
        let (_, response) = try await request("GET", path: "/v2/user")
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - HostingPort

    public func deploy(projectPath: String, environment: HostingEnvironment) async throws -> Deployment {
        // POST /v13/deployments
        let body: [String: Any] = [
            "name": environment.name.lowercased(),
            "target": environment.isProduction ? "production" : "preview",
            "gitSource": [
                "type": "github",
                "ref": environment.branch ?? "main",
            ],
        ]

        let (data, _) = try await request("POST", path: "/v13/deployments", body: body)
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? UUID().uuidString,
            projectId: json["projectId"] as? String ?? projectPath,
            environmentId: environment.id,
            commitHash: (json["meta"] as? [String: Any])?["githubCommitSha"] as? String,
            status: mapDeploymentState(json["readyState"] as? String),
            url: (json["url"] as? String).map { "https://\($0)" },
            createdAt: parseDate(json["createdAt"]) ?? .now
        )
    }

    public func deployments(projectId: String) async throws -> [Deployment] {
        // GET /v6/deployments?projectId=...
        var query = "projectId=\(projectId)&limit=20"
        if let teamId { query += "&teamId=\(teamId)" }

        let (data, _) = try await request("GET", path: "/v6/deployments?\(query)")
        let json = try jsonObject(from: data)

        guard let items = json["deployments"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = item["uid"] as? String ?? item["id"] as? String else { return nil }
            return Deployment(
                id: id,
                projectId: item["projectId"] as? String ?? projectId,
                environmentId: (item["target"] as? String) ?? "preview",
                commitHash: (item["meta"] as? [String: Any])?["githubCommitSha"] as? String,
                status: mapDeploymentState(item["readyState"] as? String ?? item["state"] as? String),
                url: (item["url"] as? String).map { "https://\($0)" },
                createdAt: parseDate(item["createdAt"]) ?? .now,
                completedAt: parseDate(item["ready"])
            )
        }
    }

    public func deploymentStatus(deploymentId: String) async throws -> Deployment {
        // GET /v13/deployments/:id
        let (data, _) = try await request("GET", path: "/v13/deployments/\(deploymentId)")
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? deploymentId,
            projectId: json["projectId"] as? String ?? "",
            environmentId: (json["target"] as? String) ?? "preview",
            commitHash: (json["meta"] as? [String: Any])?["githubCommitSha"] as? String,
            status: mapDeploymentState(json["readyState"] as? String),
            url: (json["url"] as? String).map { "https://\($0)" },
            createdAt: parseDate(json["createdAt"]) ?? .now,
            completedAt: parseDate(json["ready"])
        )
    }

    public func rollback(deploymentId: String) async throws -> Deployment {
        // POST /v9/projects/:projectId/rollback
        // First get the deployment to find the project
        let deployment = try await deploymentStatus(deploymentId: deploymentId)

        let body: [String: Any] = [
            "deploymentId": deploymentId
        ]

        let (data, _) = try await request("POST", path: "/v9/projects/\(deployment.projectId)/rollback", body: body)
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? UUID().uuidString,
            projectId: deployment.projectId,
            environmentId: deployment.environmentId,
            commitHash: deployment.commitHash,
            status: .deploying,
            url: deployment.url,
            createdAt: .now
        )
    }

    public func environments(projectId: String) async throws -> [HostingEnvironment] {
        // Vercel uses "targets" rather than named environments.
        // Return standard production + preview environments.
        let deploys = try await deployments(projectId: projectId)

        var envMap: [String: HostingEnvironment] = [:]

        for deploy in deploys {
            let target = deploy.environmentId
            if envMap[target] == nil {
                let isProduction = target == "production"
                envMap[target] = HostingEnvironment(
                    id: target,
                    name: target.capitalized,
                    branch: isProduction ? "main" : nil,
                    url: deploy.url,
                    isProduction: isProduction
                )
            }
        }

        if envMap.isEmpty {
            return [
                HostingEnvironment(id: "production", name: "Production", branch: "main", isProduction: true),
                HostingEnvironment(id: "preview", name: "Preview"),
            ]
        }

        return Array(envMap.values).sorted { $0.isProduction && !$1.isProduction }
    }

    public func buildLogs(deploymentId: String) async throws -> [BuildLog] {
        // GET /v7/deployments/:id/events
        let (data, _) = try await request("GET", path: "/v7/deployments/\(deploymentId)/events")

        // Vercel returns NDJSON (newline-delimited JSON)
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        var logs: [BuildLog] = []

        for (index, line) in lines.enumerated() {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            let message = json["text"] as? String ?? json["payload"] as? String ?? ""
            guard !message.isEmpty else { continue }

            let type = json["type"] as? String ?? "info"
            let level: BuildLogLevel = switch type {
            case "error": .error
            case "warning": .warning
            case "debug": .debug
            default: .info
            }

            logs.append(BuildLog(
                id: "log-\(deploymentId)-\(index)",
                deploymentId: deploymentId,
                timestamp: parseDate(json["created"]) ?? .now,
                level: level,
                message: message
            ))
        }

        return logs
    }

    public func environmentVariables(environmentId: String) async throws -> [String: String] {
        // GET /v9/projects/:projectId/env
        // environmentId here is treated as projectId since Vercel scopes env vars to projects
        var path = "/v9/projects/\(environmentId)/env"
        if let teamId { path += "?teamId=\(teamId)" }

        let (data, _) = try await request("GET", path: path)
        let json = try jsonObject(from: data)

        guard let envs = json["envs"] as? [[String: Any]] else { return [:] }

        var result: [String: String] = [:]
        for env in envs {
            if let key = env["key"] as? String {
                // Vercel may not return decrypted values for secrets
                let value = env["value"] as? String ?? "(encrypted)"
                result[key] = value
            }
        }
        return result
    }

    public func setEnvironmentVariable(environmentId: String, key: String, value: String) async throws {
        // POST /v10/projects/:projectId/env
        var path = "/v10/projects/\(environmentId)/env"
        if let teamId { path += "?teamId=\(teamId)" }

        let body: [String: Any] = [
            "key": key,
            "value": value,
            "type": "encrypted",
            "target": ["production", "preview", "development"],
        ]

        _ = try await request("POST", path: path, body: body)
    }

    // MARK: - Private Helpers

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw VercelAdapterError.invalidURL(path)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw VercelAdapterError.apiError(httpResponse.statusCode, errorBody)
        }

        return (data, response)
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VercelAdapterError.invalidResponse
        }
        return json
    }

    private func mapDeploymentState(_ state: String?) -> DeploymentStatus {
        switch state?.uppercased() {
        case "READY": .ready
        case "BUILDING": .building
        case "DEPLOYING": .deploying
        case "QUEUED", "INITIALIZING": .queued
        case "ERROR": .failed
        case "CANCELED": .cancelled
        default: .queued
        }
    }

    private func parseDate(_ value: Any?) -> Date? {
        if let ms = value as? Int {
            return Date(timeIntervalSince1970: Double(ms) / 1000.0)
        }
        if let ms = value as? Double {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        if let str = value as? String, let ms = Double(str) {
            return Date(timeIntervalSince1970: ms / 1000.0)
        }
        return nil
    }
}

// MARK: - Errors

public enum VercelAdapterError: LocalizedError {
    case invalidURL(String)
    case apiError(Int, String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path): "Invalid URL: \(path)"
        case .apiError(let code, let body): "Vercel API error (\(code)): \(body)"
        case .invalidResponse: "Invalid response from Vercel API"
        }
    }
}
