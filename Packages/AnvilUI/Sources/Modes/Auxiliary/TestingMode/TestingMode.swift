import SwiftUI

struct TestingMode: View {
    @StateObject private var viewModel = TestingViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        if viewModel.suites.isEmpty {
            AnvilEmptyState(
                icon: "testtube.2",
                title: "No test suites",
                message: "Run your test suite or load demo data to get started.",
                actions: [
                    EmptyStateAction("Run Tests", icon: "play.fill", style: .primary) {
                        viewModel.projectPath = appState.currentProjectPath
                        if viewModel.projectPath == nil {
                            viewModel.loadDemoData()
                        }
                        viewModel.runAllTests()
                    },
                    EmptyStateAction("Load Demo Data", icon: "tray.and.arrow.down", style: .secondary) {
                        viewModel.loadDemoData()
                    }
                ]
            )
        } else {
            HSplitView {
                // Left: Test tree
                TestSuiteList(viewModel: viewModel)
                    .frame(minWidth: 280, idealWidth: 320)

                // Right: Detail view
                TestDetailView(viewModel: viewModel)
                    .frame(minWidth: 400)
            }
        }
    }
}

// MARK: - Test Suite List

struct TestSuiteList: View {
    @ObservedObject var viewModel: TestingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    if viewModel.isRunning {
                        viewModel.stopTests()
                    } else {
                        viewModel.runAllTests()
                    }
                } label: {
                    Image(systemName: viewModel.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(viewModel.isRunning ? AnvilColor.accentRed : AnvilColor.accentGreen)
                }
                .buttonStyle(.plain)
                .help(viewModel.isRunning ? "Stop Tests" : "Run All Tests")

                Divider().frame(height: 14)

                // Filter buttons
                HStack(spacing: 2) {
                    ForEach(TestingViewModel.TestFilter.allCases, id: \.rawValue) { filter in
                        filterButton(filter)
                    }
                }

                Spacer()

                // Summary
                if viewModel.totalTests > 0 {
                    HStack(spacing: AnvilSpacing.xxs) {
                        if viewModel.passedTests > 0 {
                            Text("\(viewModel.passedTests)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentGreen)
                        }
                        if viewModel.failedTests > 0 {
                            Text("\(viewModel.failedTests)")
                                .font(AnvilFont.label)
                                .foregroundStyle(AnvilColor.accentRed)
                        }
                    }
                }
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.bar)

            Divider()

            // Search
            if !viewModel.suites.isEmpty {
                AnvilSearchField(text: $viewModel.filterText, placeholder: "Filter tests...")
                Divider()
            }

            // Test tree
            List {
                ForEach(viewModel.filteredSuites) { suite in
                    TestSuiteRow(suite: suite, viewModel: viewModel)
                }
            }
            .listStyle(.sidebar)
        }
    }

    @ViewBuilder
    private func filterButton(_ filter: TestingViewModel.TestFilter) -> some View {
        let isActive = viewModel.showFilter == filter

        Button {
            viewModel.showFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Suite Row

struct TestSuiteRow: View {
    let suite: TestSuite
    @ObservedObject var viewModel: TestingViewModel

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { suite.isExpanded },
            set: { _ in viewModel.toggleSuiteExpansion(suite.id) }
        )) {
            ForEach(suite.tests) { test in
                TestCaseRow(test: test, isSelected: viewModel.selectedTestId == test.id) {
                    viewModel.selectedTestId = test.id
                } onRun: {
                    viewModel.runTest(test.id)
                }
            }
        } label: {
            HStack(spacing: AnvilSpacing.xs) {
                statusIcon(suite.overallStatus)

                Text(suite.name)
                    .font(AnvilFont.sidebarItem)
                    .lineLimit(1)

                Spacer()

                // Pass/fail counts
                HStack(spacing: 3) {
                    if suite.passedCount > 0 {
                        Text("\(suite.passedCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                    if suite.failedCount > 0 {
                        Text("\(suite.failedCount)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(AnvilColor.accentRed)
                    }
                }

                // Run suite button
                Button {
                    viewModel.runSuite(suite.id)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Test Case Row

struct TestCaseRow: View {
    let test: TestCase
    let isSelected: Bool
    let onSelect: () -> Void
    let onRun: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AnvilSpacing.xs) {
                statusIcon(test.status)

                Text(test.name)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                if test.durationMs > 0 {
                    Text(formatDuration(test.durationMs))
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                }

                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Detail View

struct TestDetailView: View {
    @ObservedObject var viewModel: TestingViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let test = viewModel.selectedTest {
                // Header
                HStack(spacing: AnvilSpacing.sm) {
                    statusIcon(test.status)
                    Text(test.name)
                        .font(AnvilFont.subheading)
                    Spacer()

                    if test.durationMs > 0 {
                        Text(formatDuration(test.durationMs))
                            .font(AnvilFont.code)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        viewModel.runTest(test.id)
                    } label: {
                        Label("Re-run", systemImage: "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AnvilColor.accentGreen)
                }
                .padding(AnvilSpacing.md)

                Divider()

                // Failure info
                if let message = test.failureMessage {
                    VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                        HStack(spacing: AnvilSpacing.xs) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AnvilColor.accentRed)
                            Text("Failure")
                                .font(AnvilFont.sidebarHeader)
                                .foregroundStyle(AnvilColor.accentRed)
                        }

                        GroupBox {
                            Text(message)
                                .font(AnvilFont.code)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let file = test.filePath, let line = test.failureLine {
                            HStack(spacing: AnvilSpacing.xs) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("\(file):\(line)")
                                    .font(AnvilFont.code)
                            }
                            .foregroundStyle(AnvilColor.accentBlue)
                        }
                    }
                    .padding(AnvilSpacing.md)

                    Divider()
                }

                // Output log
                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    Text("Output")
                        .font(.headline)

                    ScrollView {
                        Text(viewModel.testOutput)
                            .font(AnvilFont.code)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AnvilSpacing.md)
            } else {
                // Summary view when no test selected
                testSummaryView
            }
        }
        .background(.background)
    }

    private var testSummaryView: some View {
        VStack(spacing: AnvilSpacing.xl) {
            Spacer()

            // Stats cards
            HStack(spacing: AnvilSpacing.lg) {
                statCard("Total", value: "\(viewModel.totalTests)", color: .primary)
                statCard("Passed", value: "\(viewModel.passedTests)", color: AnvilColor.accentGreen)
                statCard("Failed", value: "\(viewModel.failedTests)", color: AnvilColor.accentRed)
                statCard("Duration", value: formatDuration(viewModel.totalDuration), color: .secondary)
            }

            if let lastRun = viewModel.lastRunDate {
                Text("Last run: \(RelativeDateTimeFormatter().localizedString(for: lastRun, relativeTo: .now))")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }

            // Progress bar
            if viewModel.totalTests > 0 {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        let passedWidth = geo.size.width * CGFloat(viewModel.passedTests) / CGFloat(viewModel.totalTests)
                        let failedWidth = geo.size.width * CGFloat(viewModel.failedTests) / CGFloat(viewModel.totalTests)
                        Rectangle().fill(AnvilColor.accentGreen).frame(width: passedWidth)
                        Rectangle().fill(AnvilColor.accentRed).frame(width: failedWidth)
                        Rectangle().fill(.quaternary)
                    }
                }
                .frame(height: 6)
                .clipShape(Capsule())
                .padding(.horizontal, AnvilSpacing.xxxl)
            }

            Spacer()
        }
    }

    private func statCard(_ label: String, value: String, color: Color) -> some View {
        GroupBox {
            VStack(spacing: AnvilSpacing.xs) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                Text(label)
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 100)
        }
    }
}

// MARK: - Shared Helpers

private func statusIcon(_ status: TestCaseStatus) -> some View {
    Group {
        switch status {
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AnvilColor.accentGreen)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(AnvilColor.accentRed)
        case .running:
            ProgressView()
                .controlSize(.mini)
        case .skipped:
            Image(systemName: "minus.circle")
                .foregroundStyle(.tertiary)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        }
    }
    .font(.system(size: 12))
    .frame(width: 14)
}

private func statusIcon(_ status: TestSuite) -> some View {
    statusIcon(status.overallStatus)
}

private func formatDuration(_ ms: Double) -> String {
    if ms < 1000 {
        return "\(Int(ms))ms"
    } else {
        return String(format: "%.1fs", ms / 1000)
    }
}
