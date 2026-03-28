import AnvilDomain
import Foundation
import Security

/// Real GitHub Issues adapter implementing TicketPort via the GitHub REST API.
///
/// Configuration:
///   - `owner`: GitHub repository owner (org or user)
///   - `repo`: GitHub repository name
///   - `token`: Personal access token or OAuth token (Bearer auth)
///
/// The token is read from the macOS Keychain at init time using the
/// Infrastructure-layer `KeychainStore`. Callers can also pass the token
/// directly for testing or when the value comes from another source
/// (e.g. env var, OAuth flow).
///
/// All network calls use `URLSession.shared` with async/await.
/// Rate-limit headers are inspected after every response; when the
/// remaining budget hits zero the adapter throws `GitHubTicketError.rateLimited`.
/// @unchecked Sendable: stored properties are immutable after init.
public final class GitHubIssuesTicketProvider: TicketPort, @unchecked Sendable {

    // MARK: - AnvilProviderDefinition

    public let providerId: String = "github-issues"
    public let providerName: String = "GitHub Issues"

    // MARK: - Configuration

    private let owner: String
    private let repo: String
    private let token: String
    private let baseURL = "https://api.github.com"
    private let session: URLSession

    // MARK: - Init

    /// Create a provider with explicit credentials.
    public init(owner: String, repo: String, token: String) {
        self.owner = owner
        self.repo = repo
        self.token = token

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer \(token)",
            "X-GitHub-Api-Version": "2022-11-28",
        ]
        self.session = URLSession(configuration: config)
    }

    /// Create a provider reading the token from KeychainStore.
    /// Returns `nil` when no token is stored.
    public convenience init?(owner: String, repo: String, keychain: KeychainStore = KeychainStore()) {
        guard let token = try? keychain.get("github.token"), !token.isEmpty else {
            return nil
        }
        self.init(owner: owner, repo: repo, token: token)
    }

    // MARK: - Connection Validation

    public func validateConnection() async throws -> Bool {
        let (_, response) = try await request("GET", path: "/user")
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - TicketPort

    public func tickets(filter: TicketFilter?) async throws -> [Ticket] {
        var query = "state=open&per_page=50"

        if let status = filter?.status {
            // GitHub states: open, closed, all
            query = "state=\(status)&per_page=50"
        }
        if let labels = filter?.labels, !labels.isEmpty {
            let joined = labels.joined(separator: ",")
            query += "&labels=\(joined)"
        }
        if let assignee = filter?.assignee {
            query += "&assignee=\(assignee)"
        }

        let (data, _) = try await request("GET", path: "/repos/\(owner)/\(repo)/issues?\(query)")

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw GitHubTicketError.invalidResponse
        }

        return items.compactMap { mapIssueToTicket($0) }
    }

    public func ticketDetail(id: String) async throws -> Ticket {
        let (data, _) = try await request("GET", path: "/repos/\(owner)/\(repo)/issues/\(id)")
        let json = try jsonObject(from: data)

        guard let ticket = mapIssueToTicket(json) else {
            throw GitHubTicketError.invalidResponse
        }
        return ticket
    }

    public func createTicket(_ draft: TicketDraft) async throws -> Ticket {
        var body: [String: Any] = [
            "title": draft.title,
            "body": draft.description,
        ]

        if !draft.labels.isEmpty {
            body["labels"] = draft.labels
        }
        if let assignee = draft.assignee {
            body["assignees"] = [assignee]
        }

        let (data, _) = try await request("POST", path: "/repos/\(owner)/\(repo)/issues", body: body)
        let json = try jsonObject(from: data)

        guard let ticket = mapIssueToTicket(json) else {
            throw GitHubTicketError.invalidResponse
        }
        return ticket
    }

    public func updateTicket(id: String, changes: TicketUpdate) async throws -> Ticket {
        var body: [String: Any] = [:]

        if let title = changes.title { body["title"] = title }
        if let description = changes.description { body["body"] = description }
        if let status = changes.status {
            // Map domain status to GitHub state
            body["state"] = (status == "closed") ? "closed" : "open"
        }
        if let labels = changes.labels { body["labels"] = labels }
        if let assignee = changes.assignee { body["assignees"] = [assignee] }

        let (data, _) = try await request("PATCH", path: "/repos/\(owner)/\(repo)/issues/\(id)", body: body)
        let json = try jsonObject(from: data)

        guard let ticket = mapIssueToTicket(json) else {
            throw GitHubTicketError.invalidResponse
        }
        return ticket
    }

    public func deleteTicket(id: String) async throws {
        // GitHub does not support deleting issues via the API.
        // The closest operation is closing the issue.
        _ = try await request("PATCH", path: "/repos/\(owner)/\(repo)/issues/\(id)", body: [
            "state": "closed",
            "state_reason": "not_planned",
        ])
    }

    public func cycles() async throws -> [Cycle] {
        // GitHub Issues has Milestones, which map roughly to Cycles.
        let (data, _) = try await request("GET", path: "/repos/\(owner)/\(repo)/milestones?state=open&per_page=30")

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> Cycle? in
            guard let id = item["number"] as? Int,
                  let title = item["title"] as? String else { return nil }

            let dueOn = (item["due_on"] as? String).flatMap { parseISO8601($0) }
            let createdAt = (item["created_at"] as? String).flatMap { parseISO8601($0) } ?? .now

            return Cycle(
                id: String(id),
                name: title,
                startDate: createdAt,
                endDate: dueOn ?? createdAt.addingTimeInterval(14 * 86400),
                velocity: nil
            )
        }
    }

    public func boards() async throws -> [Board] {
        // GitHub Issues does not have native boards (Projects v2 is a separate API).
        // Return a default board reflecting issue states.
        let columns = [
            BoardColumn(name: "Open", status: "open"),
            BoardColumn(name: "In Progress", status: "in_progress"),
            BoardColumn(name: "Closed", status: "closed"),
        ]
        return [Board(name: "\(owner)/\(repo)", columns: columns)]
    }

    public func relations(ticketId: String) async throws -> [TicketRelation] {
        // GitHub has no first-class issue relations.
        // A future version could parse "Fixes #N" / "Depends on #N" from the body.
        return []
    }

    public func addRelation(type: TicketRelationType, source: String, target: String) async throws {
        // Not supported natively by GitHub Issues.
        throw GitHubTicketError.unsupportedOperation("GitHub Issues does not support issue relations")
    }

    public func moveToStatus(ticketId: String, status: String) async throws {
        let ghState: String
        switch status.lowercased() {
        case "closed", "done", "resolved":
            ghState = "closed"
        default:
            ghState = "open"
        }

        _ = try await request("PATCH", path: "/repos/\(owner)/\(repo)/issues/\(ticketId)", body: [
            "state": ghState,
        ])
    }

    // MARK: - Networking

    private func request(
        _ method: String,
        path: String,
        body: [String: Any]? = nil
    ) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw GitHubTicketError.invalidURL(path)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method

        if let body {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubTicketError.invalidResponse
        }

        // Check rate limiting
        if let remainingStr = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remaining = Int(remainingStr), remaining == 0 {
            let resetTime = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap { Double($0) }
                .map { Date(timeIntervalSince1970: $0) }
            throw GitHubTicketError.rateLimited(resetsAt: resetTime)
        }

        switch httpResponse.statusCode {
        case 200...299:
            return (data, response)
        case 401, 403:
            throw GitHubTicketError.authenticationFailed
        case 404:
            throw GitHubTicketError.notFound
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            throw GitHubTicketError.apiError(httpResponse.statusCode, errorBody)
        }
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GitHubTicketError.invalidResponse
        }
        return json
    }

    // MARK: - Mapping

    private func mapIssueToTicket(_ json: [String: Any]) -> Ticket? {
        // GitHub issue numbers are integers; use them as the domain ID.
        guard let number = json["number"] as? Int,
              let title = json["title"] as? String else {
            return nil
        }

        let state = json["state"] as? String ?? "open"
        let body = json["body"] as? String ?? ""

        // Labels
        let labelsArray = json["labels"] as? [[String: Any]] ?? []
        let labels = labelsArray.compactMap { $0["name"] as? String }

        // Assignee
        let assignee = (json["assignee"] as? [String: Any])?["login"] as? String

        // Priority from labels (convention: priority/critical, priority/high, etc.)
        let priority = priorityFromLabels(labels)

        // Dates
        let createdAt = (json["created_at"] as? String).flatMap { parseISO8601($0) } ?? .now
        let updatedAt = (json["updated_at"] as? String).flatMap { parseISO8601($0) } ?? createdAt

        // Milestone as epic
        let epicId = (json["milestone"] as? [String: Any])?["number"].map { "\($0)" }

        return Ticket(
            id: String(number),
            title: title,
            description: body,
            status: state,
            priority: priority,
            assignee: assignee,
            labels: labels,
            dueDate: nil,
            storyPoints: nil,
            epicId: epicId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func priorityFromLabels(_ labels: [String]) -> TicketPriority {
        for label in labels {
            let lower = label.lowercased()
            if lower.contains("critical") || lower.contains("p0") { return .critical }
            if lower.contains("high") || lower.contains("p1") { return .high }
            if lower.contains("medium") || lower.contains("p2") { return .medium }
            if lower.contains("low") || lower.contains("p3") { return .low }
        }
        return .none
    }

    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private nonisolated(unsafe) static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private func parseISO8601(_ string: String) -> Date? {
        Self.iso8601Formatter.date(from: string)
            ?? Self.iso8601FormatterNoFraction.date(from: string)
    }
}

// MARK: - Errors

public enum GitHubTicketError: LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case authenticationFailed
    case notFound
    case rateLimited(resetsAt: Date?)
    case apiError(Int, String)
    case unsupportedOperation(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path):
            "Invalid GitHub API URL: \(path)"
        case .invalidResponse:
            "Invalid response from GitHub API"
        case .authenticationFailed:
            "GitHub authentication failed. Check your token."
        case .notFound:
            "GitHub resource not found"
        case .rateLimited(let resetsAt):
            if let resetsAt {
                "GitHub API rate limit exceeded. Resets at \(resetsAt)"
            } else {
                "GitHub API rate limit exceeded"
            }
        case .apiError(let code, let body):
            "GitHub API error (\(code)): \(body)"
        case .unsupportedOperation(let reason):
            reason
        }
    }
}
