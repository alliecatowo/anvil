import SwiftUI
import AnvilDomain

struct BuildLogView: View {
    @ObservedObject var viewModel: ShipViewModel

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Build Logs")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                if let env = viewModel.selectedEnvironment {
                    AnvilBadge(text: env.environment.name, color: AnvilColor.accentBlue)
                }

                Text("\(viewModel.buildLogs.count) lines")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(AnvilSpacing.lg)

            Divider().overlay(AnvilColor.borderSubtle)

            // Log viewer
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.buildLogs) { log in
                            logLine(log)
                                .id(log.id)
                        }
                    }
                    .padding(AnvilSpacing.md)
                }
                .onChange(of: viewModel.buildLogs.count) { _, _ in
                    if let lastLog = viewModel.buildLogs.last {
                        withAnimation(AnvilAnimation.standard) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(hex: 0x0A0A0A))
        }
        .background(AnvilColor.backgroundPrimary)
    }

    // MARK: - Log Line

    private func logLine(_ log: BuildLog) -> some View {
        HStack(alignment: .top, spacing: AnvilSpacing.md) {
            // Timestamp
            Text(timeFormatter.string(from: log.timestamp))
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 65, alignment: .leading)

            // Level indicator
            Text(levelPrefix(log.level))
                .font(AnvilFont.code)
                .foregroundStyle(levelColor(log.level))
                .frame(width: 40, alignment: .leading)

            // Message
            Text(log.message)
                .font(AnvilFont.code)
                .foregroundStyle(messageColor(log.level))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AnvilSpacing.xxxs)
    }

    // MARK: - Helpers

    private func levelPrefix(_ level: BuildLogLevel) -> String {
        switch level {
        case .debug: "DBG"
        case .info: "INF"
        case .warning: "WRN"
        case .error: "ERR"
        }
    }

    private func levelColor(_ level: BuildLogLevel) -> Color {
        switch level {
        case .debug: AnvilColor.textTertiary
        case .info: AnvilColor.accentBlue
        case .warning: AnvilColor.accentAmber
        case .error: AnvilColor.accentRed
        }
    }

    private func messageColor(_ level: BuildLogLevel) -> Color {
        switch level {
        case .debug: AnvilColor.textTertiary
        case .info: AnvilColor.textPrimary
        case .warning: AnvilColor.accentAmber
        case .error: AnvilColor.accentRed
        }
    }
}
