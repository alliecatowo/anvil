import Foundation
import AnvilDomain

/// Sentry observability adapter implementing ObservabilityPort using the Sentry REST API.
/// Supports fetching errors, error details with stack traces, alerts, and metrics.
///
/// Configuration:
///   - `authToken`: Sentry auth token (required)
///   - `organization`: Sentry organization slug (required)
/// @unchecked Sendable: All stored properties are immutable after init (let bindings + URLSession).
public final class SentryObservabilityAdapter: ObservabilityPort, @unchecked Sendable {
    public let providerId: String = "sentry"
    public let providerName: String = "Sentry"

    private let authToken: String
    private let organization: String
    private let baseURL = "https://sentry.io/api/0"
    private let session: URLSession

    public init(authToken: String, organization: String) {
        self.authToken = authToken
        self.organization = organization
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(authToken)",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    // MARK: - AnvilProviderDefinition

    public func validateConnection() async throws -> Bool {
        let (_, response) = try await request("GET", path: "/organizations/\(organization)/")
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    // MARK: - ObservabilityPort

    public func errors(projectId: String, timeRange: TimeRange?) async throws -> [ErrorEvent] {
        // GET /projects/:org/:project/issues/
        var query = "query=is:unresolved&sort=date"
        if let range = timeRange {
            let start = ISO8601DateFormatter().string(from: range.start)
            let end = ISO8601DateFormatter().string(from: range.end)
            query += "&start=\(start)&end=\(end)"
        }

        let (data, _) = try await request("GET", path: "/projects/\(organization)/\(projectId)/issues/?\(query)")

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> ErrorEvent? in
            guard let id = item["id"] as? String else { return nil }

            let title = item["title"] as? String ?? "Unknown Error"
            let culprit = item["culprit"] as? String ?? ""
            let count = (item["count"] as? String).flatMap(Int.init) ?? item["count"] as? Int ?? 1
            let isResolved = (item["status"] as? String) == "resolved"

            let metadata = item["metadata"] as? [String: Any]
            let message = metadata?["value"] as? String ?? culprit

            let tags = extractTags(from: item)

            return ErrorEvent(
                id: id,
                title: title,
                message: message,
                stackTrace: nil, // Not included in list endpoint
                occurrences: count,
                firstSeen: parseISO8601(item["firstSeen"] as? String) ?? .now,
                lastSeen: parseISO8601(item["lastSeen"] as? String) ?? .now,
                isResolved: isResolved,
                tags: tags
            )
        }
    }

    public func errorDetail(errorId: String) async throws -> ErrorEvent {
        // GET /issues/:issue_id/
        let (issueData, _) = try await request("GET", path: "/issues/\(errorId)/")
        let issue = try jsonObject(from: issueData)

        // GET /issues/:issue_id/events/latest/ for stack trace
        let (eventData, _) = try await request("GET", path: "/issues/\(errorId)/events/latest/")
        let event = try jsonObject(from: eventData)

        let title = issue["title"] as? String ?? "Unknown Error"
        let metadata = issue["metadata"] as? [String: Any]
        let message = metadata?["value"] as? String ?? issue["culprit"] as? String ?? ""
        let count = (issue["count"] as? String).flatMap(Int.init) ?? issue["count"] as? Int ?? 1
        let isResolved = (issue["status"] as? String) == "resolved"

        // Extract stack trace from the latest event
        let stackTrace = extractStackTrace(from: event)
        let tags = extractTags(from: issue)

        return ErrorEvent(
            id: errorId,
            title: title,
            message: message,
            stackTrace: stackTrace,
            occurrences: count,
            firstSeen: parseISO8601(issue["firstSeen"] as? String) ?? .now,
            lastSeen: parseISO8601(issue["lastSeen"] as? String) ?? .now,
            isResolved: isResolved,
            tags: tags
        )
    }

    public func alerts(projectId: String) async throws -> [Alert] {
        // GET /projects/:org/:project/rules/
        let (data, _) = try await request("GET", path: "/projects/\(organization)/\(projectId)/rules/")

        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item -> Alert? in
            guard let id = item["id"] as? String else { return nil }

            let name = item["name"] as? String ?? "Alert Rule"
            let conditions = item["conditions"] as? [[String: Any]] ?? []
            let query = conditions.first?["name"] as? String ?? ""

            // Sentry alert rules don't have a simple threshold; extract from conditions if possible
            let actions = item["actions"] as? [[String: Any]] ?? []
            let frequency = item["frequency"] as? Int ?? 0

            let status: AlertStatus = switch item["status"] as? String {
            case "active": .ok
            case "disabled": .resolved
            default: .ok
            }

            return Alert(
                id: id,
                name: name,
                query: query,
                threshold: Double(frequency),
                status: status,
                triggeredAt: parseISO8601(item["lastTriggered"] as? String),
                acknowledgedAt: nil
            )
        }
    }

    public func acknowledgeAlert(alertId: String) async throws {
        // Sentry doesn't have a direct "acknowledge" for alert rules.
        // Mute the alert rule instead.
        _ = try await request("PUT", path: "/projects/\(organization)/_/rules/\(alertId)/snooze/", body: [
            "target": "me"
        ])
    }

    public func resolveAlert(alertId: String) async throws {
        // Disable the alert rule
        _ = try await request("PUT", path: "/projects/\(organization)/_/rules/\(alertId)/", body: [
            "status": "disabled"
        ])
    }

    public func metrics(projectId: String, query: String, timeRange: TimeRange?) async throws -> [Metric] {
        // GET /organizations/:org/events-stats/
        // Use the Discover query endpoint for metrics
        var params = "field=count()&field=count_unique(user)&project=\(projectId)&query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"

        if let range = timeRange {
            let formatter = ISO8601DateFormatter()
            params += "&start=\(formatter.string(from: range.start))&end=\(formatter.string(from: range.end))"
        } else {
            params += "&statsPeriod=24h"
        }

        let (data, _) = try await request("GET", path: "/organizations/\(organization)/events-stats/?\(params)")
        let json = try jsonObject(from: data)

        // Parse the time series data
        guard let dataPoints = json["data"] as? [[Any]] else {
            return []
        }

        return dataPoints.compactMap { point -> Metric? in
            guard point.count >= 2,
                  let timestamp = point[0] as? Double,
                  let values = point[1] as? [[String: Any]],
                  let firstValue = values.first,
                  let count = (firstValue["count"] as? Double) ?? (firstValue["count"] as? Int).map({ Double($0) }) else {
                return nil
            }

            return Metric(
                name: query.isEmpty ? "events" : query,
                value: count,
                unit: "count",
                timestamp: Date(timeIntervalSince1970: timestamp),
                tags: ["project": projectId]
            )
        }
    }

    public func createAlert(name: String, query: String, threshold: Double) async throws -> Alert {
        // POST /projects/:org/:project/rules/
        // Use a generic project slug; callers should provide it via query
        let projectSlug = query.components(separatedBy: ":").last ?? "_"

        let body: [String: Any] = [
            "name": name,
            "actionMatch": "all",
            "filterMatch": "all",
            "conditions": [
                [
                    "id": "sentry.rules.conditions.event_frequency.EventFrequencyCondition",
                    "value": Int(threshold),
                    "comparisonType": "count",
                    "interval": "1h",
                    "name": query,
                ]
            ],
            "actions": [
                [
                    "id": "sentry.rules.actions.notify_event.NotifyEventAction",
                    "name": "Send a notification to all legacy integrations",
                ]
            ],
            "frequency": 60,
        ]

        let (data, _) = try await request("POST", path: "/projects/\(organization)/\(projectSlug)/rules/", body: body)
        let json = try jsonObject(from: data)

        return Alert(
            id: json["id"] as? String ?? UUID().uuidString,
            name: name,
            query: query,
            threshold: threshold,
            status: .ok
        )
    }

    // MARK: - Private Helpers

    private func request(_ method: String, path: String, body: [String: Any]? = nil) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else {
            throw SentryAdapterError.invalidURL(path)
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
            throw SentryAdapterError.apiError(httpResponse.statusCode, errorBody)
        }

        return (data, response)
    }

    private func jsonObject(from data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SentryAdapterError.invalidResponse
        }
        return json
    }

    private func extractStackTrace(from event: [String: Any]) -> String? {
        // Navigate: entries -> exception -> values -> stacktrace -> frames
        guard let entries = event["entries"] as? [[String: Any]] else { return nil }

        for entry in entries {
            guard entry["type"] as? String == "exception",
                  let exceptionData = entry["data"] as? [String: Any],
                  let values = exceptionData["values"] as? [[String: Any]] else {
                continue
            }

            var lines: [String] = []
            for value in values {
                let type = value["type"] as? String ?? "Error"
                let message = value["value"] as? String ?? ""
                lines.append("\(type): \(message)")

                if let stacktrace = value["stacktrace"] as? [String: Any],
                   let frames = stacktrace["frames"] as? [[String: Any]] {
                    for frame in frames.reversed() {
                        let filename = frame["filename"] as? String ?? frame["absPath"] as? String ?? "<unknown>"
                        let function = frame["function"] as? String ?? "<anonymous>"
                        let lineNo = frame["lineNo"] as? Int
                        let colNo = frame["colNo"] as? Int

                        var location = "  at \(function) (\(filename)"
                        if let line = lineNo {
                            location += ":\(line)"
                            if let col = colNo { location += ":\(col)" }
                        }
                        location += ")"
                        lines.append(location)
                    }
                }
            }

            if !lines.isEmpty {
                return lines.joined(separator: "\n")
            }
        }

        return nil
    }

    private func extractTags(from item: [String: Any]) -> [String: String] {
        var tags: [String: String] = [:]
        if let level = item["level"] as? String { tags["level"] = level }
        if let platform = item["platform"] as? String { tags["platform"] = platform }
        if let tagList = item["tags"] as? [[String: String]] {
            for tag in tagList {
                if let key = tag["key"], let value = tag["value"] {
                    tags[key] = value
                }
            }
        }
        return tags
    }

    private func parseISO8601(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}

// MARK: - Errors

public enum SentryAdapterError: LocalizedError {
    case invalidURL(String)
    case apiError(Int, String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let path): "Invalid URL: \(path)"
        case .apiError(let code, let body): "Sentry API error (\(code)): \(body)"
        case .invalidResponse: "Invalid response from Sentry API"
        }
    }
}
