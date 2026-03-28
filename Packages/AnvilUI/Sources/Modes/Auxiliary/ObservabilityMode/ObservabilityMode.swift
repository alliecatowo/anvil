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
                    .accessibilityLabel("Running...")
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

        // Wire the adapter via DependencyContainer (keeps Infrastructure out of UI)
        container.connectSentry(token: viewModel.sentryToken, organization: viewModel.sentryOrg)

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
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(metric.title)
                            .font(AnvilFont.sidebarItem)
                        Text(metric.value)
                            .font(AnvilFont.code)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(metric.title): \(metric.value)")
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

