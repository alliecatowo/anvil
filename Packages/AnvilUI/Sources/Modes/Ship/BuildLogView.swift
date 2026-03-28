import SwiftUI
import AnvilDomain

struct BuildLogView: View {
    @ObservedObject var viewModel: ShipViewModel
    @State private var filterLevel: BuildLogLevel?
    @State private var searchText: String = ""
    @State private var autoScroll: Bool = true

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private var filteredLogs: [BuildLog] {
        var logs = viewModel.buildLogsForSelected
        if let level = filterLevel {
            logs = logs.filter { $0.level == level }
        }
        if !searchText.isEmpty {
            logs = logs.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        return logs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: AnvilSpacing.md) {
                Text("Build Logs")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)

                Spacer()

                // Streaming toggle
                if let envID = viewModel.selectedEnvironmentID {
                    Button {
                        if viewModel.isStreamingLogs {
                            viewModel.stopLogStreaming()
                        } else {
                            viewModel.startLogStreaming(for: envID)
                        }
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Circle()
                                .fill(viewModel.isStreamingLogs ? AnvilColor.accentGreen : AnvilColor.textTertiary)
                                .frame(width: 6, height: 6)
                            Text(viewModel.isStreamingLogs ? "Live" : "Stream")
                                .font(AnvilFont.label)
                                .foregroundStyle(viewModel.isStreamingLogs ? AnvilColor.accentGreen : AnvilColor.textSecondary)
                        }
                        .padding(.horizontal, AnvilSpacing.sm)
                        .padding(.vertical, AnvilSpacing.xxxs)
                        .background(viewModel.isStreamingLogs ? AnvilColor.accentGreen.opacity(0.1) : AnvilColor.backgroundTertiary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if let env = viewModel.selectedEnvironment {
                    AnvilBadge(text: env.environment.name, color: AnvilColor.accentBlue)
                }

                Text("\(filteredLogs.count) lines")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(AnvilSpacing.lg)

            // Filter bar
            HStack(spacing: AnvilSpacing.md) {
                // Search
                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.code)
                    .frame(maxWidth: 260)

                // Level filters
                ForEach([BuildLogLevel.info, .warning, .error, .debug], id: \.rawValue) { level in
                    Button {
                        if filterLevel == level {
                            filterLevel = nil
                        } else {
                            filterLevel = level
                        }
                    } label: {
                        Text(levelPrefix(level))
                            .font(AnvilFont.code)
                            .foregroundStyle(filterLevel == level ? .primary : levelColor(level))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Auto-scroll toggle
                Button {
                    autoScroll.toggle()
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: autoScroll ? "arrow.down.to.line" : "arrow.down.to.line")
                            .font(.system(size: 10))
                        Text("Auto-scroll")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(autoScroll ? AnvilColor.accentBlue : AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)

                // Clear
                Button {
                    searchText = ""
                    filterLevel = nil
                } label: {
                    Text("Clear Filters")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.vertical, AnvilSpacing.sm)
            .background(.bar)

            Divider()

            // Log viewer
            ScrollViewReader { proxy in
                List {
                    if filteredLogs.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No Logs Yet" : "No Matching Logs",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    } else {
                        ForEach(Array(filteredLogs.enumerated()), id: \.element.id) { index, log in
                            logLine(log, lineNumber: index + 1)
                                .id(log.id)
                                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                                .listRowBackground(log.level == .error ? AnvilColor.accentRed.opacity(0.05) : Color.clear)
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: viewModel.buildLogs.count) { _, _ in
                    if autoScroll, let lastLog = filteredLogs.last {
                        withAnimation(AnvilAnimation.standard) {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(AnvilColor.backgroundPrimary)
        .onDisappear {
            viewModel.stopLogStreaming()
        }
    }

    // MARK: - Log Line

    private func logLine(_ log: BuildLog, lineNumber: Int) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, AnvilSpacing.sm)

            // Timestamp
            Text(timeFormatter.string(from: log.timestamp))
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 85, alignment: .leading)

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
