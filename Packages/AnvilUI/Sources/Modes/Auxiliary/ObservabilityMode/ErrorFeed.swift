import SwiftUI
import AnvilDomain

struct ErrorFeed: View {
    @ObservedObject var viewModel: ObservabilityViewModel

    private let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        List {
            if !viewModel.alerts.isEmpty {
                Section {
                    ForEach(viewModel.alerts) { alert in
                        alertRow(alert)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Alert: \(alert.name), status: \(alert.status.rawValue)")
                            .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    }
                } header: {
                    Label("Alerts", systemImage: "bell.badge")
                        .font(AnvilFont.label)
                }
            }

            Section {
                ForEach(viewModel.errors) { error in
                    errorRow(error)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                }
            } header: {
                if !viewModel.alerts.isEmpty {
                    Label("Errors", systemImage: "exclamationmark.triangle")
                        .font(AnvilFont.label)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Alert Row

    private func alertRow(_ alert: AnvilDomain.Alert) -> some View {
        VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
            HStack(spacing: AnvilSpacing.sm) {
                Image(systemName: alertIcon(for: alert.status))
                    .font(.system(size: 14))
                    .foregroundStyle(alertColor(for: alert.status))
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.name)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)

                    HStack(spacing: AnvilSpacing.xs) {
                        Text(alert.status.rawValue.capitalized)
                            .font(AnvilFont.label)
                            .foregroundStyle(alertColor(for: alert.status))

                        if let triggered = alert.triggeredAt {
                            Text("Triggered \(timeFormatter.localizedString(for: triggered, relativeTo: .now))")
                                .font(AnvilFont.label)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Spacer()

                HStack(spacing: AnvilSpacing.xs) {
                    if alert.status != .acknowledged && alert.status != .resolved {
                        Button {
                            viewModel.acknowledgeAlert(alertId: alert.id)
                        } label: {
                            Label("Acknowledge", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if alert.status != .resolved {
                        Button {
                            viewModel.resolveAlert(alertId: alert.id)
                        } label: {
                            Label("Resolve", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    }
                }
            }
        }
    }

    private func alertIcon(for status: AlertStatus) -> String {
        switch status {
        case .critical: "bell.badge.fill"
        case .warning: "bell.trianglebadge.exclamationmark"
        case .acknowledged: "checkmark.circle"
        case .resolved: "checkmark.seal"
        case .ok: "bell"
        }
    }

    private func alertColor(for status: AlertStatus) -> Color {
        switch status {
        case .critical: AnvilColor.accentRed
        case .warning: AnvilColor.accentAmber
        case .acknowledged: AnvilColor.accentBlue
        case .resolved: AnvilColor.accentGreen
        case .ok: AnvilColor.textSecondary
        }
    }

    // MARK: - Error Row

    private func errorRow(_ item: ErrorItem) -> some View {
        HStack(spacing: AnvilSpacing.md) {
            // Severity icon
            Image(systemName: item.severity.icon)
                .font(.system(size: 14))
                .foregroundStyle(item.severity.color)
                .frame(width: 20)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: AnvilSpacing.xxs) {
                HStack {
                    Text(item.event.title)
                        .font(AnvilFont.sidebarItem)
                        .lineLimit(1)

                    Spacer()

                    // Count badge
                    AnvilBadge(
                        text: "\(item.event.occurrences)",
                        color: item.severity.color
                    )
                }

                HStack(spacing: AnvilSpacing.sm) {
                    // Service tag
                    if let service = item.event.tags["service"] {
                        Text(service)
                            .font(AnvilFont.code)
                            .foregroundStyle(.tertiary)
                    }

                    Text("·")
                        .foregroundStyle(.tertiary)

                    // First seen
                    Text("First: \(timeFormatter.localizedString(for: item.event.firstSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)

                    Text("·")
                        .foregroundStyle(.tertiary)

                    // Last seen
                    Text("Last: \(timeFormatter.localizedString(for: item.event.lastSeen, relativeTo: .now))")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.event.title), \(item.severity.rawValue), \(item.event.occurrences) occurrences")
        .listRowBackground(viewModel.selectedErrorID == item.id ? Color.accentColor.opacity(0.14) : Color.clear)
        .onTapGesture {
            viewModel.selectedErrorID = item.id
        }
    }
}
