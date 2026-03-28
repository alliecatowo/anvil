import SwiftUI
import AnvilDomain
import AnvilApplication

struct ObservabilityMode: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel = ObservabilityViewModel()

    var body: some View {
        Group {
            if viewModel.isConnected || viewModel.usingDemoData {
                connectedView
            } else {
                connectView
            }
        }
        .onAppear {
            viewModel.configure(service: container.observabilityService)
            // Auto-connect if Sentry adapter already wired via Settings
            if container.observabilityPort != nil && container.observabilityService.isConnected {
                viewModel.isConnected = true
                Task { await viewModel.refresh() }
            }
        }
    }

    // MARK: - Connected View

    private var connectedView: some View {
        HStack(spacing: 0) {
            // Left panel: error feed
            VStack(spacing: 0) {
                tabSelector
                Divider()
                errorFeedOrMetrics
            }
            .frame(width: 480)

            Divider()

            // Right panel: detail or metrics dashboard
            Group {
                switch viewModel.selectedTab {
                case .errors:
                    if let selected = viewModel.selectedError {
                        ErrorDetailView(error: selected)
                    } else {
                        noSelectionPlaceholder
                    }
                case .metrics:
                    MetricsDashboard(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Connect View

    private var connectView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Spacer()

            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 44, weight: .thin))
                .foregroundStyle(.tertiary)

            Text("Connect to Sentry")
                .font(AnvilFont.heading)

            Text("Monitor errors, performance, and alerts from your Sentry project")
                .font(AnvilFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(spacing: AnvilSpacing.sm) {
                HStack(spacing: AnvilSpacing.sm) {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("Organization")
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                        TextField("my-org", text: $viewModel.sentryOrg)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)
                    }

                    VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                        Text("Project")
                            .font(AnvilFont.label)
                            .foregroundStyle(.tertiary)
                        TextField("my-project", text: $viewModel.sentryProject)
                            .textFieldStyle(.roundedBorder)
                            .font(AnvilFont.code)
                    }
                }
                .frame(maxWidth: 500)

                VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                    Text("Auth Token")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                    SecureField("sntrys_...", text: $viewModel.sentryToken)
                        .textFieldStyle(.roundedBorder)
                        .font(AnvilFont.code)
                }
                .frame(maxWidth: 500)
            }

            HStack(spacing: AnvilSpacing.md) {
                Button("Connect") {
                    Task { await connectSentry() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.sentryOrg.isEmpty || viewModel.sentryProject.isEmpty || viewModel.sentryToken.isEmpty || viewModel.isLoading)

                Button("Use Demo Data") {
                    viewModel.loadDemoData()
                }
                .buttonStyle(.bordered)
            }

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentRed)
                    .padding(.top, AnvilSpacing.xs)
                    .frame(maxWidth: 400)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Pre-fill from Keychain if available
            if let org = ProviderKeychain.sentryOrganization { viewModel.sentryOrg = org }
            if let token = ProviderKeychain.sentryToken { viewModel.sentryToken = token }
        }
    }

    private func connectSentry() async {
        // Save to Keychain
        ProviderKeychain.sentryToken = viewModel.sentryToken
        ProviderKeychain.sentryOrganization = viewModel.sentryOrg

        // Wire the adapter into the service
        container.observabilityService.setAdapter(
            SentryObservabilityAdapterFactory.create(
                token: viewModel.sentryToken,
                organization: viewModel.sentryOrg
            )
        )

        await viewModel.connectToSentry()
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(ObservabilityTab.allCases, id: \.rawValue) { tab in
                Button {
                    viewModel.selectedTab = tab
                } label: {
                    HStack(spacing: AnvilSpacing.xs) {
                        Text(tab.rawValue)
                            .font(AnvilFont.label)
                            .foregroundStyle(
                                viewModel.selectedTab == tab
                                    ? .primary
                                    : .tertiary
                            )

                        if tab == .errors && viewModel.criticalCount > 0 {
                            AnvilBadge(
                                text: "\(viewModel.criticalCount)",
                                color: AnvilColor.accentRed
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(
                        viewModel.selectedTab == tab
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Refresh / Disconnect buttons
            HStack(spacing: AnvilSpacing.xs) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Refresh")
                .disabled(viewModel.usingDemoData)

                Button {
                    viewModel.disconnect()
                } label: {
                    Image(systemName: "eject")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Disconnect")
            }
            .padding(.trailing, AnvilSpacing.sm)

            if viewModel.usingDemoData {
                Text("Demo")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(AnvilColor.accentAmber)
                    .padding(.horizontal, AnvilSpacing.xs)
                    .padding(.vertical, 2)
                    .background(AnvilColor.accentAmber.opacity(0.15), in: RoundedRectangle(cornerRadius: 3))
                    .padding(.trailing, AnvilSpacing.sm)
            }
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .padding(.vertical, AnvilSpacing.xs)
    }

    // MARK: - Conditional Content

    @ViewBuilder
    private var errorFeedOrMetrics: some View {
        switch viewModel.selectedTab {
        case .errors:
            ErrorFeed(viewModel: viewModel)
        case .metrics:
            metricsQuickList
        }
    }

    private var metricsQuickList: some View {
        List {
            ForEach(viewModel.metrics) { metric in
                HStack(spacing: AnvilSpacing.sm) {
                    Image(systemName: metric.trend.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(metric.trend.color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.title)
                            .font(AnvilFont.sidebarItem)
                        Text(metric.value)
                            .font(AnvilFont.code)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
        .listStyle(.inset)
    }

    private var noSelectionPlaceholder: some View {
        ContentUnavailableView {
            Label("No Selection", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Select an error to view details")
        }
    }
}

// MARK: - Sentry Adapter Factory

/// Factory to create the Sentry adapter without importing AnvilInfrastructure.
/// The actual adapter is injected from the App target; this protocol allows
/// ObservabilityMode to create adapters from user-entered credentials.
enum SentryObservabilityAdapterFactory {
    /// Creates an ObservabilityPort adapter. Uses the adapter already registered
    /// in DependencyContainer if available, or creates one via the Application layer.
    @MainActor
    static func create(token: String, organization: String) -> any ObservabilityPort {
        // Return a lightweight proxy that delegates to the real adapter
        // The real SentryObservabilityAdapter is wired from App/AnvilApp.swift
        SentryObservabilityProxy(token: token, organization: organization)
    }
}

/// Lightweight proxy implementing ObservabilityPort using URLSession directly.
/// This allows the UI to create a Sentry connection without importing Infrastructure.
/// @unchecked Sendable: All stored properties (token, organization, baseURL, session) are immutable after init.
private final class SentryObservabilityProxy: ObservabilityPort, @unchecked Sendable {
    let providerId = "sentry"
    let providerName = "Sentry"

    private let token: String
    private let organization: String
    private let baseURL = "https://sentry.io/api/0"
    private let session: URLSession

    init(token: String, organization: String) {
        self.token = token
        self.organization = organization
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: config)
    }

    func validateConnection() async throws -> Bool {
        guard let url = URL(string: "\(baseURL)/organizations/\(organization)/") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (_, response) = try await session.data(for: req)
        return (response as? HTTPURLResponse)?.statusCode == 200
    }

    func errors(projectId: String, timeRange: TimeRange?) async throws -> [ErrorEvent] {
        var query = "query=is:unresolved&sort=date"
        if let range = timeRange {
            let fmt = ISO8601DateFormatter()
            query += "&start=\(fmt.string(from: range.start))&end=\(fmt.string(from: range.end))"
        }
        let data = try await get("/projects/\(organization)/\(projectId)/issues/?\(query)")
        guard let items = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return items.compactMap { item -> ErrorEvent? in
            guard let id = item["id"] as? String else { return nil }
            let title = item["title"] as? String ?? "Unknown"
            let metadata = item["metadata"] as? [String: Any]
            let message = metadata?["value"] as? String ?? item["culprit"] as? String ?? ""
            let count = (item["count"] as? String).flatMap(Int.init) ?? item["count"] as? Int ?? 1
            let isResolved = (item["status"] as? String) == "resolved"
            var tags: [String: String] = [:]
            if let level = item["level"] as? String { tags["level"] = level }
            if let platform = item["platform"] as? String { tags["platform"] = platform }
            return ErrorEvent(
                id: id, title: title, message: message,
                occurrences: count,
                firstSeen: parseDate(item["firstSeen"] as? String) ?? .now,
                lastSeen: parseDate(item["lastSeen"] as? String) ?? .now,
                isResolved: isResolved, tags: tags
            )
        }
    }

    func errorDetail(errorId: String) async throws -> ErrorEvent {
        let issueData = try await get("/issues/\(errorId)/")
        let issue = try JSONSerialization.jsonObject(with: issueData) as? [String: Any] ?? [:]
        let eventData = try await get("/issues/\(errorId)/events/latest/")
        let event = try JSONSerialization.jsonObject(with: eventData) as? [String: Any] ?? [:]

        let title = issue["title"] as? String ?? "Unknown"
        let metadata = issue["metadata"] as? [String: Any]
        let message = metadata?["value"] as? String ?? ""
        let count = (issue["count"] as? String).flatMap(Int.init) ?? 1
        let stackTrace = extractStackTrace(from: event)
        var tags: [String: String] = [:]
        if let level = issue["level"] as? String { tags["level"] = level }

        return ErrorEvent(
            id: errorId, title: title, message: message,
            stackTrace: stackTrace, occurrences: count,
            firstSeen: parseDate(issue["firstSeen"] as? String) ?? .now,
            lastSeen: parseDate(issue["lastSeen"] as? String) ?? .now,
            tags: tags
        )
    }

    func alerts(projectId: String) async throws -> [AnvilDomain.Alert] { [] }
    func acknowledgeAlert(alertId: String) async throws {}
    func resolveAlert(alertId: String) async throws {}

    func metrics(projectId: String, query: String, timeRange: TimeRange?) async throws -> [Metric] {
        var params = "field=count()&project=\(projectId)"
        if let range = timeRange {
            let fmt = ISO8601DateFormatter()
            params += "&start=\(fmt.string(from: range.start))&end=\(fmt.string(from: range.end))"
        } else {
            params += "&statsPeriod=24h"
        }
        let qEnc = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        params += "&query=\(qEnc)"

        let data = try await get("/organizations/\(organization)/events-stats/?\(params)")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let points = json["data"] as? [[Any]] else { return [] }

        return points.compactMap { point -> Metric? in
            guard point.count >= 2,
                  let ts = point[0] as? Double,
                  let vals = point[1] as? [[String: Any]],
                  let first = vals.first,
                  let count = (first["count"] as? Double) ?? (first["count"] as? Int).map({ Double($0) }) else { return nil }
            return Metric(name: "events", value: count, unit: "count", timestamp: Date(timeIntervalSince1970: ts))
        }
    }

    func createAlert(name: String, query: String, threshold: Double) async throws -> AnvilDomain.Alert {
        AnvilDomain.Alert(name: name, query: query, threshold: threshold)
    }

    // MARK: - Helpers

    private func get(_ path: String) async throws -> Data {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw URLError(.init(rawValue: http.statusCode))
        }
        return data
    }

    private func parseDate(_ str: String?) -> Date? {
        guard let str else { return nil }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str)
    }

    private func extractStackTrace(from event: [String: Any]) -> String? {
        guard let entries = event["entries"] as? [[String: Any]] else { return nil }
        for entry in entries {
            guard entry["type"] as? String == "exception",
                  let data = entry["data"] as? [String: Any],
                  let values = data["values"] as? [[String: Any]] else { continue }
            var lines: [String] = []
            for value in values {
                let type = value["type"] as? String ?? "Error"
                let msg = value["value"] as? String ?? ""
                lines.append("\(type): \(msg)")
                if let st = value["stacktrace"] as? [String: Any],
                   let frames = st["frames"] as? [[String: Any]] {
                    for frame in frames.reversed() {
                        let file = frame["filename"] as? String ?? frame["absPath"] as? String ?? "<unknown>"
                        let fn = frame["function"] as? String ?? "<anonymous>"
                        var loc = "  at \(fn) (\(file)"
                        if let line = frame["lineNo"] as? Int {
                            loc += ":\(line)"
                            if let col = frame["colNo"] as? Int { loc += ":\(col)" }
                        }
                        loc += ")"
                        lines.append(loc)
                    }
                }
            }
            if !lines.isEmpty { return lines.joined(separator: "\n") }
        }
        return nil
    }
}
