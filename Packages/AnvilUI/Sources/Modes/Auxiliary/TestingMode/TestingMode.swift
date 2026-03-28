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
            .background(AnvilColor.backgroundPrimary)
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
            .background(AnvilColor.backgroundSecondary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Search
            if !viewModel.suites.isEmpty {
                AnvilSearchField(text: $viewModel.filterText, placeholder: "Filter tests...")
                Divider().overlay(AnvilColor.borderSubtle)
            }

            // Test tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.filteredSuites) { suite in
                        TestSuiteRow(suite: suite, viewModel: viewModel)
                    }
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }

    private func filterButton(_ filter: TestingViewModel.TestFilter) -> some View {
        Button {
            viewModel.showFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 10, weight: viewModel.showFilter == filter ? .semibold : .regular))
                .foregroundStyle(viewModel.showFilter == filter ? AnvilColor.textPrimary : AnvilColor.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(viewModel.showFilter == filter ? AnvilColor.backgroundTertiary : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Suite Row

struct TestSuiteRow: View {
    let suite: TestSuite
    @ObservedObject var viewModel: TestingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Suite header
            Button {
                viewModel.toggleSuiteExpansion(suite.id)
            } label: {
                HStack(spacing: AnvilSpacing.xs) {
                    Image(systemName: suite.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                        .frame(width: 12)

                    statusIcon(suite.overallStatus)

                    Text(suite.name)
                        .font(AnvilFont.sidebarItem)
                        .foregroundStyle(AnvilColor.textPrimary)
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
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Tests (when expanded)
            if suite.isExpanded {
                ForEach(suite.tests) { test in
                    TestCaseRow(test: test, isSelected: viewModel.selectedTestId == test.id) {
                        viewModel.selectedTestId = test.id
                    } onRun: {
                        viewModel.runTest(test.id)
                    }
                }
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
                Color.clear.frame(width: 12) // indent

                statusIcon(test.status)

                Text(test.name)
                    .font(AnvilFont.sidebarItem)
                    .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                    .lineLimit(1)

                Spacer()

                if test.durationMs > 0 {
                    Text(formatDuration(test.durationMs))
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Button(action: onRun) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.leading, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xxs)
            .background(isSelected ? AnvilColor.selectionBackground : .clear)
            .contentShape(Rectangle())
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
                        .foregroundStyle(AnvilColor.textPrimary)
                    Spacer()

                    if test.durationMs > 0 {
                        Text(formatDuration(test.durationMs))
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Button {
                        viewModel.runTest(test.id)
                    } label: {
                        HStack(spacing: AnvilSpacing.xxs) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                            Text("Re-run")
                                .font(AnvilFont.label)
                        }
                        .foregroundStyle(AnvilColor.accentGreen)
                        .padding(.horizontal, AnvilSpacing.sm)
                        .padding(.vertical, AnvilSpacing.xxs)
                        .background(AnvilColor.accentGreen.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(AnvilSpacing.md)

                Divider().overlay(AnvilColor.borderSubtle)

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

                        Text(message)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(AnvilSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AnvilColor.accentRed.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

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

                    Divider().overlay(AnvilColor.borderSubtle)
                }

                // Output log
                VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                    Text("OUTPUT")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                        .tracking(0.3)

                    ScrollView {
                        Text(viewModel.testOutput)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(AnvilSpacing.md)
            } else {
                // Summary view when no test selected
                testSummaryView
            }
        }
        .background(AnvilColor.backgroundPrimary)
    }

    private var testSummaryView: some View {
        VStack(spacing: AnvilSpacing.xl) {
            Spacer()

            // Stats cards
            HStack(spacing: AnvilSpacing.lg) {
                statCard("Total", value: "\(viewModel.totalTests)", color: AnvilColor.textPrimary)
                statCard("Passed", value: "\(viewModel.passedTests)", color: AnvilColor.accentGreen)
                statCard("Failed", value: "\(viewModel.failedTests)", color: AnvilColor.accentRed)
                statCard("Duration", value: formatDuration(viewModel.totalDuration), color: AnvilColor.textSecondary)
            }

            if let lastRun = viewModel.lastRunDate {
                Text("Last run: \(RelativeDateTimeFormatter().localizedString(for: lastRun, relativeTo: .now))")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            // Progress bar
            if viewModel.totalTests > 0 {
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        let passedWidth = geo.size.width * CGFloat(viewModel.passedTests) / CGFloat(viewModel.totalTests)
                        let failedWidth = geo.size.width * CGFloat(viewModel.failedTests) / CGFloat(viewModel.totalTests)
                        Rectangle().fill(AnvilColor.accentGreen).frame(width: passedWidth)
                        Rectangle().fill(AnvilColor.accentRed).frame(width: failedWidth)
                        Rectangle().fill(AnvilColor.borderMedium)
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
        VStack(spacing: AnvilSpacing.xs) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(width: 100)
        .padding(AnvilSpacing.md)
        .background(AnvilColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
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
                .foregroundStyle(AnvilColor.textTertiary)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(AnvilColor.textTertiary)
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
