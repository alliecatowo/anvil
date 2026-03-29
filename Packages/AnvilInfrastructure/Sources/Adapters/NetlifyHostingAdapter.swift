import Foundation
import AnvilDomain

/// Netlify hosting adapter implementing HostingPort using the Netlify REST API v1.
/// Supports deploy, list deployments, get logs, manage env vars.
///
/// Configuration:
///   - `apiToken`: Netlify personal access token (required)
///   - `siteId`: Netlify site ID or name (required for deploy operations)
/// @unchecked Sendable: All stored properties are immutable after init (let bindings + URLSession).
public final class NetlifyHostingAdapter: HostingPort, @unchecked Sendable {
    public let providerId: String = "netlify"
    public let providerName: String = "Netlify"

    private let apiToken: String
    private let siteId: String?
    private let baseURL = "https://api.netlify.com/api/v1"
    private let session: URLSession

    public init(apiToken: String, siteId: String? = nil) {
        self.apiToken = apiToken
        self.siteId = siteId
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(apiToken)",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        // GET /user to validate the token
        let (_, response) = try await request("GET", path: "/user")
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - HostingPort

    public func deploy(projectPath: String, environment: HostingEnvironment) async throws -> Deployment {
        // POST /sites/:site_id/deploys — trigger a new deploy
        guard let siteId else {
            throw NetlifyAdapterError.missingSiteId
        }

        let body: [String: Any] = [
            "branch": environment.branch ?? "main",
            "production": environment.isProduction,
        ]

        let (data, _) = try await request("POST", path: "/sites/\(siteId)/deploys", body: body)
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? UUID().uuidString,
            projectId: json["site_id"] as? String ?? projectPath,
            environmentId: environment.id,
            commitHash: json["commit_ref"] as? String,
            status: mapDeployState(json["state"] as? String),
            url: (json["ssl_url"] as? String) ?? (json["url"] as? String),
            createdAt: parseISO8601(json["created_at"] as? String) ?? .now
        )
    }

    public func deployments(projectId: String) async throws -> [Deployment] {
        // GET /sites/:site_id/deploys
        let effectiveSiteId = siteId ?? projectId
        let (data, _) = try await request("GET", path: "/sites/\(effectiveSiteId)/deploys?per_page=20")

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return Deployment(
                id: id,
                projectId: item["site_id"] as? String ?? projectId,
                environmentId: (item["context"] as? String) ?? "production",
                commitHash: item["commit_ref"] as? String,
                status: mapDeployState(item["state"] as? String),
                url: (item["ssl_url"] as? String) ?? (item["url"] as? String),
                createdAt: parseISO8601(item["created_at"] as? String) ?? .now,
                completedAt: parseISO8601(item["published_at"] as? String)
            )
        }
    }

    public func deploymentStatus(deploymentId: String) async throws -> Deployment {
        // GET /deploys/:deploy_id
        let (data, _) = try await request("GET", path: "/deploys/\(deploymentId)")
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? deploymentId,
            projectId: json["site_id"] as? String ?? "",
            environmentId: (json["context"] as? String) ?? "production",
            commitHash: json["commit_ref"] as? String,
            status: mapDeployState(json["state"] as? String),
            url: (json["ssl_url"] as? String) ?? (json["url"] as? String),
            createdAt: parseISO8601(json["created_at"] as? String) ?? .now,
            completedAt: parseISO8601(json["published_at"] as? String)
        )
    }

    public func rollback(deploymentId: String) async throws -> Deployment {
        // POST /sites/:site_id/rollback — restore a previous deploy
        guard let siteId else {
            throw NetlifyAdapterError.missingSiteId
        }

        let body: [String: Any] = [
            "deploy_id": deploymentId
        ]

        // Netlify: POST /sites/:site_id/rollback with deploy_id restores that deploy
        let (data, _) = try await request("POST", path: "/sites/\(siteId)/rollback", body: body)
        let json = try jsonObject(from: data)

        return Deployment(
            id: json["id"] as? String ?? UUID().uuidString,
            projectId: json["site_id"] as? String ?? siteId,
            environmentId: (json["context"] as? String) ?? "production",
            commitHash: json["commit_ref"] as? String,
            status: .deploying,
            url: (json["ssl_url"] as? String) ?? (json["url"] as? String),
            createdAt: .now
        )
    }

    public func environments(projectId: String) async throws -> [HostingEnvironment] {
        // Netlify uses "contexts": production, deploy-preview, branch-deploy.
        // Fetch the site to get production branch and URL.
        let effectiveSiteId = siteId ?? projectId
        let (data, _) = try await request("GET", path: "/sites/\(effectiveSiteId)")
        let json = try jsonObject(from: data)

        let productionBranch = (json["default_domain"] as? String) != nil
            ? (json["build_settings"] as? [String: Any])?["production_branch"] as? String ?? "main"
            : "main"
        let siteURL = json["ssl_url"] as? String ?? json["url"] as? String

        return [
            HostingEnvironment(
                id: "production",
                name: "Production",
                branch: productionBranch,
                url: siteURL,
                isProduction: true
            ),
            HostingEnvironment(
                id: "deploy-preview",
                name: "Deploy Preview"
            ),
            HostingEnvironment(
                id: "branch-deploy",
                name: "Branch Deploy"
            ),
        ]
    }

    public func buildLogs(deploymentId: String) async throws -> [BuildLog] {
        // GET /deploys/:deploy_id/log — returns plain text log lines
        // Netlify also supports /builds/:build_id/log for build output
        let (data, _) = try await request("GET", path: "/deploys/\(deploymentId)/log")

        // Netlify returns JSON array of log entry objects
        guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Fall back: treat as plain text
            guard let text = String(data: data, encoding: .utf8) else { return [] }
            return text.components(separatedBy: "\n")
                .filter { !$0.isEmpty }
                .enumerated()
                .map { index, line in
                    BuildLog(
                        id: "log-\(deploymentId)-\(index)",
                        deploymentId: deploymentId,
                        timestamp: .now,
                        level: .info,
                        message: line
                    )
                }
        }

        return entries.enumerated().compactMap { index, entry in
            let message = entry["message"] as? String ?? ""
            guard !message.isEmpty else { return nil }

            let section = entry["section"] as? String ?? "info"
            let level: BuildLogLevel = switch section {
            case "error": .error
            case "warning": .warning
            case "debug": .debug
            default: .info
            }

            return BuildLog(
                id: "log-\(deploymentId)-\(index)",
                deploymentId: deploymentId,
                timestamp: parseISO8601(entry["ts"] as? String) ?? .now,
                level: level,
                message: message
            )
        }
    }

    public func environmentVariables(environmentId: String) async throws -> [String: String] {
        // GET /accounts/:account_slug/env or GET /sites/:site_id/env
        guard let siteId else {
            throw NetlifyAdapterError.missingSiteId
        }

        let (data, _) = try await request("GET", path: "/sites/\(siteId)/env")

        guard let envVars = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return [:]
        }

        var result: [String: String] = [:]
        for envVar in envVars {
            if let key = envVar["key"] as? String,
               let values = envVar["values"] as? [[String: Any]],
               let latestValue = values.first?["value"] as? String {
                result[key] = latestValue
            }
        }
        return result
    }

    public func setEnvironmentVariable(environmentId: String, key: String, value: String) async throws {
        // POST /sites/:site_id/env
        guard let siteId else {
            throw NetlifyAdapterError.missingSiteId
        }

        let body: [[String: Any]] = [[
            "key": key,
            "values": [
                [
                    "value": value,
                    "context": "all",
                ]
            ],
        ]]

        // Netlify expects an array at the top level for env var creation
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let url = URL(string: baseURL + "/sites/\(siteId)/env") else {
            throw NetlifyAdapterError.invalidURL("/sites/\(siteId)/env")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = bodyData

        let (responseData, response) = try await session.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode >= 400 {
            let errorBody = String(data: responseData, encoding: .utf8) ?? ""
            throw NetlifyAdapterError.apiError(httpResponse.statusCode, errorBody)
        }
    }

    // MARK: - Private Helpers

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw NetlifyAdapterError.invalidURL(path)
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
            throw NetlifyAdapterError.apiError(httpResponse.statusCode, errorBody)
        }

        return (data, response)
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetlifyAdapterError.invalidResponse
        }
        return json
    }

    private func mapDeployState(_ state: String?) -> DeploymentStatus {
        switch state?.lowercased() {
        case "ready": .ready
        case "building": .building
        case "deploying", "uploading", "uploaded", "processing": .deploying
        case "enqueued", "new": .queued
        case "error": .failed
        case "cancelled": .cancelled
        default: .queued
        }
    }

    nonisolated(unsafe) private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        return Self.iso8601Formatter.date(from: string)
            ?? ISO8601DateFormatter().date(from: string)
    }
}

// MARK: - Errors

public enum NetlifyAdapterError: LocalizedError {
    case invalidURL(String)
    case apiError(Int, String)
    case invalidResponse
    case missingSiteId

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path): "Invalid URL: \(path)"
        case .apiError(let code, let body): "Netlify API error (\(code)): \(body)"
        case .invalidResponse: "Invalid response from Netlify API"
        case .missingSiteId: "Netlify site ID is required for this operation"
        }
    }
}
