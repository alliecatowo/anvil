import AnvilDomain
import Foundation

/// Real Linear adapter implementing TicketPort via the Linear GraphQL API.
///
/// Configuration:
///   - `apiKey`: Linear personal API key (Authorization header)
///   - `teamId`: Linear team identifier to scope queries (optional -- when nil,
///     queries return issues across all accessible teams)
///
/// All network calls use `URLSession.shared` with async/await.
/// @unchecked Sendable: stored properties are immutable after init.
public final class LinearTicketProvider: TicketPort, @unchecked Sendable {

    // MARK: - AnvilProviderDefinition

    public let providerId: String = "linear"
    public let providerName: String = "Linear"

    // MARK: - Configuration

    private let apiKey: String
    private let teamId: String?
    private let endpoint = "https://api.linear.app/graphql"
    private let session: URLSession

    // MARK: - Init

    /// Create a provider with explicit credentials.
    public init(apiKey: String, teamId: String? = nil) {
        self.apiKey = apiKey
        self.teamId = teamId

        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": apiKey,
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    /// Create a provider reading the API key from KeychainStore.
    /// Returns `nil` when no key is stored.
    public convenience init?(teamId: String? = nil, keychain: KeychainStore = KeychainStore()) {
        guard let key = try? keychain.get("linear.apiKey"), !key.isEmpty else {
            return nil
        }
        self.init(apiKey: key, teamId: teamId)
    }

    // MARK: - Connection Validation

    public func validateConnection() async throws -> Bool {
        let query = "{ viewer { id name } }"
        let result = try await graphql(query: query)
        return (result["viewer"] as? [String: Any])?["id"] != nil
    }

    // MARK: - TicketPort

    public func tickets(filter: TicketFilter?) async throws -> [Ticket] {
        var filterClauses: [String] = []

        if let teamId {
            filterClauses.append("team: { id: { eq: \"\(escape(teamId))\" } }")
        }
        if let status = filter?.status {
            filterClauses.append("state: { name: { eqIgnoreCase: \"\(escape(status))\" } }")
        }
        if let assignee = filter?.assignee {
            filterClauses.append("assignee: { name: { eqIgnoreCase: \"\(escape(assignee))\" } }")
        }
        if let labels = filter?.labels, !labels.isEmpty {
            let labelNames = labels.map { "\"\(escape($0))\"" }.joined(separator: ", ")
            filterClauses.append("labels: { name: { in: [\(labelNames)] } }")
        }
        if let priority = filter?.priority {
            filterClauses.append("priority: { eq: \(mapPriorityToLinear(priority)) }")
        }

        let filterArg = filterClauses.isEmpty ? "" : "(filter: { \(filterClauses.joined(separator: ", ")) })"

        let query = """
        {
            issues\(filterArg) {
                nodes {
                    id
                    identifier
                    title
                    description
                    priority
                    state { name }
                    assignee { name }
                    labels { nodes { name } }
                    dueDate
                    estimate
                    cycle { id }
                    createdAt
                    updatedAt
                }
            }
        }
        """

        let result = try await graphql(query: query)
        guard let issues = result["issues"] as? [String: Any],
              let nodes = issues["nodes"] as? [[String: Any]] else {
            return []
        }

        return nodes.compactMap { mapNodeToTicket($0) }
    }

    public func ticketDetail(id: String) async throws -> Ticket {
        let query = """
        {
            issue(id: "\(escape(id))") {
                id
                identifier
                title
                description
                priority
                state { name }
                assignee { name }
                labels { nodes { name } }
                dueDate
                estimate
                cycle { id }
                createdAt
                updatedAt
            }
        }
        """

        let result = try await graphql(query: query)
        guard let issueData = result["issue"] as? [String: Any],
              let ticket = mapNodeToTicket(issueData) else {
            throw LinearTicketError.notFound
        }
        return ticket
    }

    public func createTicket(_ draft: TicketDraft) async throws -> Ticket {
        var inputFields: [String] = [
            "title: \"\(escape(draft.title))\"",
        ]
        if !draft.description.isEmpty {
            inputFields.append("description: \"\(escape(draft.description))\"")
        }
        if let teamId {
            inputFields.append("teamId: \"\(escape(teamId))\"")
        }
        inputFields.append("priority: \(mapPriorityToLinear(draft.priority))")
        if let assignee = draft.assignee {
            inputFields.append("assigneeId: \"\(escape(assignee))\"")
        }

        let input = inputFields.joined(separator: ", ")

        let mutation = """
        mutation {
            issueCreate(input: { \(input) }) {
                success
                issue {
                    id
                    identifier
                    title
                    description
                    priority
                    state { name }
                    assignee { name }
                    labels { nodes { name } }
                    dueDate
                    estimate
                    cycle { id }
                    createdAt
                    updatedAt
                }
            }
        }
        """

        let result = try await graphql(query: mutation)
        guard let createResult = result["issueCreate"] as? [String: Any],
              let success = createResult["success"] as? Bool, success,
              let issueData = createResult["issue"] as? [String: Any],
              let ticket = mapNodeToTicket(issueData) else {
            throw LinearTicketError.mutationFailed("issueCreate")
        }
        return ticket
    }

    public func updateTicket(id: String, changes: TicketUpdate) async throws -> Ticket {
        var inputFields: [String] = []

        if let title = changes.title {
            inputFields.append("title: \"\(escape(title))\"")
        }
        if let description = changes.description {
            inputFields.append("description: \"\(escape(description))\"")
        }
        if let status = changes.status {
            // Linear uses state IDs, but we accept state names here.
            // The API also accepts stateId; for name-based lookup the caller
            // should resolve the stateId before calling updateTicket.
            inputFields.append("stateId: \"\(escape(status))\"")
        }
        if let priority = changes.priority {
            inputFields.append("priority: \(mapPriorityToLinear(priority))")
        }
        if let assignee = changes.assignee {
            inputFields.append("assigneeId: \"\(escape(assignee))\"")
        }
        if let dueDate = changes.dueDate {
            let formatted = Self.dateFormatter.string(from: dueDate)
            inputFields.append("dueDate: \"\(formatted)\"")
        }
        if let estimate = changes.storyPoints {
            inputFields.append("estimate: \(estimate)")
        }

        guard !inputFields.isEmpty else {
            // Nothing to update; just return the current ticket.
            return try await ticketDetail(id: id)
        }

        let input = inputFields.joined(separator: ", ")

        let mutation = """
        mutation {
            issueUpdate(id: "\(escape(id))", input: { \(input) }) {
                success
                issue {
                    id
                    identifier
                    title
                    description
                    priority
                    state { name }
                    assignee { name }
                    labels { nodes { name } }
                    dueDate
                    estimate
                    cycle { id }
                    createdAt
                    updatedAt
                }
            }
        }
        """

        let result = try await graphql(query: mutation)
        guard let updateResult = result["issueUpdate"] as? [String: Any],
              let success = updateResult["success"] as? Bool, success,
              let issueData = updateResult["issue"] as? [String: Any],
              let ticket = mapNodeToTicket(issueData) else {
            throw LinearTicketError.mutationFailed("issueUpdate")
        }
        return ticket
    }

    public func deleteTicket(id: String) async throws {
        let mutation = """
        mutation {
            issueArchive(id: "\(escape(id))") {
                success
            }
        }
        """
        let result = try await graphql(query: mutation)
        guard let archiveResult = result["issueArchive"] as? [String: Any],
              let success = archiveResult["success"] as? Bool, success else {
            throw LinearTicketError.mutationFailed("issueArchive")
        }
    }

    public func cycles() async throws -> [Cycle] {
        var filterArg = ""
        if let teamId {
            filterArg = "(filter: { team: { id: { eq: \"\(escape(teamId))\" } } })"
        }

        let query = """
        {
            cycles\(filterArg) {
                nodes {
                    id
                    name
                    number
                    startsAt
                    endsAt
                    completedScopeHistory
                    issues { nodes { id } }
                }
            }
        }
        """

        let result = try await graphql(query: query)
        guard let cyclesData = result["cycles"] as? [String: Any],
              let nodes = cyclesData["nodes"] as? [[String: Any]] else {
            return []
        }

        return nodes.compactMap { node -> Cycle? in
            guard let id = node["id"] as? String else { return nil }
            let name = node["name"] as? String
                ?? (node["number"] as? Int).map { "Cycle \($0)" }
                ?? id

            let startDate = (node["startsAt"] as? String).flatMap { parseISO8601($0) } ?? .now
            let endDate = (node["endsAt"] as? String).flatMap { parseISO8601($0) } ?? startDate.addingTimeInterval(14 * 86400)

            let issueNodes = (node["issues"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
            let ticketIds = issueNodes.compactMap { $0["id"] as? String }

            let scopeHistory = node["completedScopeHistory"] as? [Int]
            let velocity = scopeHistory?.last

            return Cycle(
                id: id,
                name: name,
                startDate: startDate,
                endDate: endDate,
                ticketIds: ticketIds,
                velocity: velocity
            )
        }
    }

    public func boards() async throws -> [Board] {
        // Linear uses workflow states as board columns.
        var filterArg = ""
        if let teamId {
            filterArg = "(id: \"\(escape(teamId))\")"
        }

        let query = """
        {
            team\(filterArg) {
                id
                name
                states {
                    nodes {
                        id
                        name
                        type
                        position
                    }
                }
            }
        }
        """

        // If no teamId, try teams list instead
        if teamId == nil {
            return try await boardsFromAllTeams()
        }

        let result = try await graphql(query: query)
        guard let teamData = result["team"] as? [String: Any] else {
            return []
        }

        return [mapTeamToBoard(teamData)].compactMap { $0 }
    }

    public func relations(ticketId: String) async throws -> [TicketRelation] {
        let query = """
        {
            issue(id: "\(escape(ticketId))") {
                relations {
                    nodes {
                        id
                        type
                        relatedIssue { id }
                    }
                }
            }
        }
        """

        let result = try await graphql(query: query)
        guard let issueData = result["issue"] as? [String: Any],
              let relations = issueData["relations"] as? [String: Any],
              let nodes = relations["nodes"] as? [[String: Any]] else {
            return []
        }

        return nodes.compactMap { node -> TicketRelation? in
            guard let id = node["id"] as? String,
                  let typeStr = node["type"] as? String,
                  let relatedIssue = node["relatedIssue"] as? [String: Any],
                  let targetId = relatedIssue["id"] as? String else {
                return nil
            }

            let relType = mapLinearRelationType(typeStr)
            return TicketRelation(id: id, type: relType, sourceId: ticketId, targetId: targetId)
        }
    }

    public func addRelation(type: TicketRelationType, source: String, target: String) async throws {
        let linearType = mapDomainRelationType(type)

        let mutation = """
        mutation {
            issueRelationCreate(input: {
                issueId: "\(escape(source))"
                relatedIssueId: "\(escape(target))"
                type: \(linearType)
            }) {
                success
            }
        }
        """

        let result = try await graphql(query: mutation)
        guard let createResult = result["issueRelationCreate"] as? [String: Any],
              let success = createResult["success"] as? Bool, success else {
            throw LinearTicketError.mutationFailed("issueRelationCreate")
        }
    }

    public func moveToStatus(ticketId: String, status: String) async throws {
        // status here should be the Linear state ID.
        _ = try await updateTicket(id: ticketId, changes: TicketUpdate(status: status))
    }

    // MARK: - GraphQL Transport

    private func graphql(query: String) async throws -> [String: Any] {
        guard let url = URL(string: endpoint) else {
            throw LinearTicketError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let payload: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LinearTicketError.invalidResponse
        }

        // Rate limiting
        if httpResponse.statusCode == 429 {
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) }
            throw LinearTicketError.rateLimited(retryAfterSeconds: retryAfter)
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            if httpResponse.statusCode == 401 {
                throw LinearTicketError.authenticationFailed
            }
            throw LinearTicketError.apiError(httpResponse.statusCode, errorBody)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinearTicketError.invalidResponse
        }

        // Check for GraphQL errors
        if let errors = json["errors"] as? [[String: Any]], let first = errors.first {
            let message = first["message"] as? String ?? "Unknown GraphQL error"
            throw LinearTicketError.graphQLError(message)
        }

        guard let resultData = json["data"] as? [String: Any] else {
            throw LinearTicketError.invalidResponse
        }

        return resultData
    }

    // MARK: - Mapping

    private func mapNodeToTicket(_ node: [String: Any]) -> Ticket? {
        guard let id = node["id"] as? String,
              let title = node["title"] as? String else {
            return nil
        }

        let description = node["description"] as? String ?? ""
        let stateName = (node["state"] as? [String: Any])?["name"] as? String ?? "Backlog"
        let assigneeName = (node["assignee"] as? [String: Any])?["name"] as? String

        // Labels
        let labelNodes = (node["labels"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []
        let labels = labelNodes.compactMap { $0["name"] as? String }

        // Priority: Linear uses 0=none, 1=urgent, 2=high, 3=medium, 4=low
        let linearPriority = node["priority"] as? Int ?? 0
        let priority = mapLinearPriority(linearPriority)

        // Dates
        let createdAt = (node["createdAt"] as? String).flatMap { parseISO8601($0) } ?? .now
        let updatedAt = (node["updatedAt"] as? String).flatMap { parseISO8601($0) } ?? createdAt
        let dueDate = (node["dueDate"] as? String).flatMap { parseDate($0) }

        let estimate = node["estimate"] as? Int
        let cycleId = (node["cycle"] as? [String: Any])?["id"] as? String

        return Ticket(
            id: id,
            title: title,
            description: description,
            status: stateName,
            priority: priority,
            assignee: assigneeName,
            labels: labels,
            dueDate: dueDate,
            storyPoints: estimate,
            epicId: cycleId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func mapLinearPriority(_ value: Int) -> TicketPriority {
        switch value {
        case 1: .critical
        case 2: .high
        case 3: .medium
        case 4: .low
        default: .none
        }
    }

    private func mapPriorityToLinear(_ priority: TicketPriority) -> Int {
        switch priority {
        case .critical: 1
        case .high: 2
        case .medium: 3
        case .low: 4
        case .none: 0
        }
    }

    private func mapLinearRelationType(_ type: String) -> TicketRelationType {
        switch type.lowercased() {
        case "blocks": .blocks
        case "blocked_by", "blockedby": .blockedBy
        case "duplicate": .duplicate
        case "related": .related
        default: .related
        }
    }

    private func mapDomainRelationType(_ type: TicketRelationType) -> String {
        switch type {
        case .blocks: "blocks"
        case .blockedBy: "blocked_by"
        case .duplicate: "duplicate"
        case .related: "related"
        case .parent: "related"
        case .child: "related"
        }
    }

    private func mapTeamToBoard(_ teamData: [String: Any]) -> Board? {
        guard let teamName = teamData["name"] as? String else { return nil }

        let stateNodes = (teamData["states"] as? [String: Any])?["nodes"] as? [[String: Any]] ?? []

        let columns = stateNodes
            .sorted { ($0["position"] as? Double ?? 0) < ($1["position"] as? Double ?? 0) }
            .compactMap { state -> BoardColumn? in
                guard let id = state["id"] as? String,
                      let name = state["name"] as? String else { return nil }
                return BoardColumn(id: id, name: name, status: name.lowercased())
            }

        return Board(name: teamName, columns: columns)
    }

    private func boardsFromAllTeams() async throws -> [Board] {
        let query = """
        {
            teams {
                nodes {
                    id
                    name
                    states {
                        nodes {
                            id
                            name
                            type
                            position
                        }
                    }
                }
            }
        }
        """

        let result = try await graphql(query: query)
        guard let teamsData = result["teams"] as? [String: Any],
              let nodes = teamsData["nodes"] as? [[String: Any]] else {
            return []
        }

        return nodes.compactMap { mapTeamToBoard($0) }
    }

    // MARK: - String Helpers

    /// Escape a string for safe embedding in a GraphQL query.
    private func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    // MARK: - Date Parsing

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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private func parseISO8601(_ string: String) -> Date? {
        Self.iso8601Formatter.date(from: string)
            ?? Self.iso8601FormatterNoFraction.date(from: string)
    }

    private func parseDate(_ string: String) -> Date? {
        Self.dateFormatter.date(from: string)
            ?? parseISO8601(string)
    }
}

// MARK: - Errors

public enum LinearTicketError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case notFound
    case rateLimited(retryAfterSeconds: Double?)
    case apiError(Int, String)
    case graphQLError(String)
    case mutationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Linear API URL"
        case .invalidResponse:
            "Invalid response from Linear API"
        case .authenticationFailed:
            "Linear authentication failed. Check your API key."
        case .notFound:
            "Linear issue not found"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                "Linear API rate limit exceeded. Retry after \(Int(retryAfter)) seconds."
            } else {
                "Linear API rate limit exceeded"
            }
        case .apiError(let code, let body):
            "Linear API error (\(code)): \(body)"
        case .graphQLError(let message):
            "Linear GraphQL error: \(message)"
        case .mutationFailed(let operation):
            "Linear mutation failed: \(operation)"
        }
    }
}
