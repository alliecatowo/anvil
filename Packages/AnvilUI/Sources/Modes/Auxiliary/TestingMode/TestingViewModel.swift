import SwiftUI
import AnvilDomain

// MARK: - Test Suite Tree

public struct TestSuite: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var tests: [TestCase]
    public var isExpanded: Bool = true

    public init(id: String = UUID().uuidString, name: String, tests: [TestCase] = [], isExpanded: Bool = true) {
        self.id = id
        self.name = name
        self.tests = tests
        self.isExpanded = isExpanded
    }

    public var passedCount: Int { tests.filter { $0.status == .passed }.count }
    public var failedCount: Int { tests.filter { $0.status == .failed }.count }
    public var totalCount: Int { tests.count }
    public var duration: Double { tests.reduce(0) { $0 + $1.durationMs } }

    public var overallStatus: TestCaseStatus {
        if tests.contains(where: { $0.status == .running }) { return .running }
        if tests.contains(where: { $0.status == .failed }) { return .failed }
        if tests.allSatisfy({ $0.status == .passed }) && !tests.isEmpty { return .passed }
        return .pending
    }
}

public struct TestCase: Identifiable, Sendable {
    public let id: String
    public let name: String
    public var status: TestCaseStatus
    public var durationMs: Double
    public var failureMessage: String?
    public var failureLine: Int?
    public var filePath: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        status: TestCaseStatus = .pending,
        durationMs: Double = 0,
        failureMessage: String? = nil,
        failureLine: Int? = nil,
        filePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.durationMs = durationMs
        self.failureMessage = failureMessage
        self.failureLine = failureLine
        self.filePath = filePath
    }
}

public enum TestCaseStatus: String, Sendable {
    case pending, running, passed, failed, skipped
}

// MARK: - ViewModel

@MainActor
public class TestingViewModel: ObservableObject {
    @Published public var suites: [TestSuite] = []
    @Published public var selectedTestId: String?
    @Published public var isRunning: Bool = false
    @Published public var filterText: String = ""
    @Published public var showFilter: TestFilter = .all
    @Published public var lastRunDate: Date?
    @Published public var testOutput: String = ""

    /// Repo root path for running package tests
    public var projectPath: String?

    private var runTask: Task<Void, Never>?

    public enum TestFilter: String, CaseIterable, Sendable {
        case all = "All"
        case failed = "Failed"
        case passed = "Passed"
        case skipped = "Skipped"
    }

    public init() {}

    // MARK: - Computed

    public var totalTests: Int {
        suites.reduce(0) { $0 + $1.totalCount }
    }

    public var passedTests: Int {
        suites.reduce(0) { $0 + $1.passedCount }
    }

    public var failedTests: Int {
        suites.reduce(0) { $0 + $1.failedCount }
    }

    public var totalDuration: Double {
        suites.reduce(0) { $0 + $1.duration }
    }

    public var filteredSuites: [TestSuite] {
        suites.compactMap { suite in
            var filtered = suite
            let matchingTests = suite.tests.filter { test in
                let matchesFilter: Bool
                switch showFilter {
                case .all: matchesFilter = true
                case .failed: matchesFilter = test.status == .failed
                case .passed: matchesFilter = test.status == .passed
                case .skipped: matchesFilter = test.status == .skipped
                }
                let matchesSearch = filterText.isEmpty || test.name.localizedCaseInsensitiveContains(filterText) || suite.name.localizedCaseInsensitiveContains(filterText)
                return matchesFilter && matchesSearch
            }
            guard !matchingTests.isEmpty else { return nil }
            filtered.tests = matchingTests
            return filtered
        }
    }

    public var selectedTest: TestCase? {
        guard let id = selectedTestId else { return nil }
        return suites.flatMap(\.tests).first { $0.id == id }
    }

    // MARK: - Actions

    public func runAllTests() {
        guard let path = projectPath else {
            // Fallback to demo simulation if no project path
            runDemoTests()
            return
        }
        executePackageTests(projectPath: path, filter: nil)
    }

    public func runSuite(_ suiteId: String) {
        guard let suite = suites.first(where: { $0.id == suiteId }) else { return }
        guard let path = projectPath else {
            runDemoSuite(suiteId)
            return
        }
        executePackageTests(projectPath: path, filter: suite.name)
    }

    public func runTest(_ testId: String) {
        for suite in suites {
            if let test = suite.tests.first(where: { $0.id == testId }) {
                guard let path = projectPath else {
                    runDemoSingleTest(testId)
                    return
                }
                executePackageTests(projectPath: path, filter: "\(suite.name)/\(test.name)")
                return
            }
        }
    }

    public func stopTests() {
        runTask?.cancel()
        runTask = nil
        isRunning = false
        testOutput += "\n--- Tests cancelled ---\n"
    }

    public func toggleSuiteExpansion(_ suiteId: String) {
        if let idx = suites.firstIndex(where: { $0.id == suiteId }) {
            suites[idx].isExpanded.toggle()
        }
    }

    // MARK: - Real Test Execution

    private func executePackageTests(projectPath: String, filter: String?) {
        isRunning = true
        testOutput = ""

        // Mark all tests as running
        for i in suites.indices {
            for j in suites[i].tests.indices {
                suites[i].tests[j].status = .running
            }
        }

        runTask = Task { [weak self] in
            guard let self else { return }

            var env = ProcessInfo.processInfo.environment
            let xcodeDevDir = "/Applications/Xcode.app/Contents/Developer"
            if FileManager.default.fileExists(atPath: xcodeDevDir) {
                env["DEVELOPER_DIR"] = xcodeDevDir
            }
            var accumulated = ""
            let packageDirectories = self.packageDirectories(in: projectPath)

            if packageDirectories.isEmpty {
                await MainActor.run {
                    self.testOutput = "No package manifests found under \(projectPath)/Packages\n"
                    self.isRunning = false
                }
                return
            }

            for packageDirectory in packageDirectories {
                if Task.isCancelled { break }

                let process = Process()
                let pipe = Pipe()

                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                var args = ["swift", "test", "--package-path", packageDirectory]
                if let filter {
                    args += ["--filter", filter]
                }
                process.arguments = args
                process.standardOutput = pipe
                process.standardError = pipe
                process.environment = env

                await MainActor.run {
                    self.testOutput += "\n==> swift test --package-path \(packageDirectory)\n"
                }

                do {
                    try process.run()
                } catch {
                    await MainActor.run {
                        self.testOutput += "Failed to start swift test for \(packageDirectory): \(error.localizedDescription)\n"
                        self.isRunning = false
                    }
                    return
                }

                let handle = pipe.fileHandleForReading

                while true {
                    if Task.isCancelled {
                        process.terminate()
                        break
                    }
                    let data = handle.availableData
                    if data.isEmpty { break }
                    if let chunk = String(data: data, encoding: .utf8) {
                        accumulated += chunk
                        await MainActor.run {
                            self.testOutput += chunk
                        }
                    }
                }

                process.waitUntilExit()
            }

            await MainActor.run {
                self.parseTestOutput(accumulated)
                self.isRunning = false
                self.lastRunDate = .now
            }
        }
    }

    private func packageDirectories(in projectPath: String) -> [String] {
        let packagesRoot = URL(fileURLWithPath: projectPath).appendingPathComponent("Packages")
        guard let packageURLs = try? FileManager.default.contentsOfDirectory(
            at: packagesRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return packageURLs
            .filter { url in
                var isDirectory: ObjCBool = false
                let packageManifest = url.appendingPathComponent("Package.swift").path
                return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    && isDirectory.boolValue
                    && FileManager.default.fileExists(atPath: packageManifest)
            }
            .map(\.path)
            .sorted()
    }

    // MARK: - Output Parsing

    private func parseTestOutput(_ output: String) {
        var parsedSuites: [String: [TestCase]] = [:]
        let lines = output.components(separatedBy: "\n")

        // XCTest output patterns:
        // Test Case '-[ModuleTests.SuiteTests testName]' started.
        // Test Case '-[ModuleTests.SuiteTests testName]' passed (0.123 seconds).
        // Test Case '-[ModuleTests.SuiteTests testName]' failed (0.456 seconds).
        //
        // Swift Testing output:
        // Test testName() started
        // Test testName() passed after 0.123 seconds

        let xcTestPassPattern = #"Test Case '-\[(\w+)\.(\w+) (\w+)\]' passed \(([\d.]+) seconds\)"#
        let xcTestFailPattern = #"Test Case '-\[(\w+)\.(\w+) (\w+)\]' failed \(([\d.]+) seconds\)"#

        let xcPassRe = try? NSRegularExpression(pattern: xcTestPassPattern)
        let xcFailRe = try? NSRegularExpression(pattern: xcTestFailPattern)

        // Track failure messages
        var lastFailureMessage: String?

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)

            // Check for failure details (lines between start and fail)
            if line.contains("XCTAssert") || line.contains("failed -") || line.contains("Expected") {
                lastFailureMessage = line.trimmingCharacters(in: .whitespaces)
            }

            // Test passed
            if let match = xcPassRe?.firstMatch(in: line, range: range) {
                let suiteName = extractGroup(line, match: match, group: 2)
                let testName = extractGroup(line, match: match, group: 3)
                let duration = Double(extractGroup(line, match: match, group: 4)) ?? 0

                let test = TestCase(
                    id: "\(suiteName).\(testName)",
                    name: testName,
                    status: .passed,
                    durationMs: duration * 1000
                )
                parsedSuites[suiteName, default: []].append(test)
                lastFailureMessage = nil
                continue
            }

            // Test failed
            if let match = xcFailRe?.firstMatch(in: line, range: range) {
                let suiteName = extractGroup(line, match: match, group: 2)
                let testName = extractGroup(line, match: match, group: 3)
                let duration = Double(extractGroup(line, match: match, group: 4)) ?? 0

                let test = TestCase(
                    id: "\(suiteName).\(testName)",
                    name: testName,
                    status: .failed,
                    durationMs: duration * 1000,
                    failureMessage: lastFailureMessage
                )
                parsedSuites[suiteName, default: []].append(test)
                lastFailureMessage = nil
                continue
            }
        }

        // Only update suites if we parsed something
        if !parsedSuites.isEmpty {
            suites = parsedSuites.map { name, tests in
                TestSuite(id: name, name: name, tests: tests)
            }.sorted { $0.name < $1.name }
        }
    }

    private func extractGroup(_ string: String, match: NSTextCheckingResult, group: Int) -> String {
        guard let range = Range(match.range(at: group), in: string) else { return "" }
        return String(string[range])
    }

    // MARK: - Demo Fallback

    public func loadDemoData() {
        suites = [
            TestSuite(name: "AuthServiceTests", tests: [
                TestCase(name: "testLoginSuccess", status: .passed, durationMs: 42),
                TestCase(name: "testLoginInvalidCredentials", status: .passed, durationMs: 38),
                TestCase(name: "testTokenRefresh", status: .failed, durationMs: 156, failureMessage: "Expected token to be refreshed within 5s, but timed out after 10s", failureLine: 47, filePath: "src/auth/auth.service.spec.ts"),
                TestCase(name: "testLogout", status: .passed, durationMs: 21),
                TestCase(name: "testSessionExpiry", status: .skipped),
            ]),
            TestSuite(name: "UserControllerTests", tests: [
                TestCase(name: "testGetProfile", status: .passed, durationMs: 67),
                TestCase(name: "testUpdateProfile", status: .passed, durationMs: 89),
                TestCase(name: "testDeleteAccount", status: .failed, durationMs: 234, failureMessage: "Foreign key constraint violation: user has active subscriptions", failureLine: 112, filePath: "src/user/user.controller.spec.ts"),
            ]),
            TestSuite(name: "PaymentIntegrationTests", tests: [
                TestCase(name: "testCreateCharge", status: .passed, durationMs: 320),
                TestCase(name: "testRefund", status: .passed, durationMs: 445),
                TestCase(name: "testWebhookProcessing", status: .passed, durationMs: 178),
            ]),
        ]
        lastRunDate = Date().addingTimeInterval(-300)
    }

    private func runDemoTests() {
        isRunning = true
        testOutput = "Running all tests...\n"

        for i in suites.indices {
            for j in suites[i].tests.indices {
                suites[i].tests[j].status = .running
            }
        }

        Task {
            try? await Task.sleep(for: .seconds(1.5))
            simulateResults()
            isRunning = false
            lastRunDate = .now
        }
    }

    private func runDemoSuite(_ suiteId: String) {
        guard let idx = suites.firstIndex(where: { $0.id == suiteId }) else { return }
        isRunning = true
        testOutput = "Running \(suites[idx].name)...\n"

        for j in suites[idx].tests.indices {
            suites[idx].tests[j].status = .running
        }

        Task {
            try? await Task.sleep(for: .seconds(1))
            simulateResultsForSuite(idx)
            isRunning = false
            lastRunDate = .now
        }
    }

    private func runDemoSingleTest(_ testId: String) {
        for i in suites.indices {
            if let j = suites[i].tests.firstIndex(where: { $0.id == testId }) {
                suites[i].tests[j].status = .running
                isRunning = true
                testOutput = "Running \(suites[i].tests[j].name)...\n"

                Task {
                    try? await Task.sleep(for: .seconds(0.5))
                    let passed = Bool.random()
                    suites[i].tests[j].status = passed ? .passed : .failed
                    suites[i].tests[j].durationMs = Double.random(in: 10...500)
                    if !passed {
                        suites[i].tests[j].failureMessage = "Expected true but got false"
                    }
                    testOutput += passed ? "PASS \(suites[i].tests[j].name)\n" : "FAIL \(suites[i].tests[j].name)\n"
                    isRunning = false
                    lastRunDate = .now
                }
                return
            }
        }
    }

    // MARK: - Simulation

    private func simulateResults() {
        for i in suites.indices {
            simulateResultsForSuite(i)
        }
    }

    private func simulateResultsForSuite(_ idx: Int) {
        for j in suites[idx].tests.indices {
            let rand = Double.random(in: 0...1)
            if rand < 0.75 {
                suites[idx].tests[j].status = .passed
            } else if rand < 0.9 {
                suites[idx].tests[j].status = .failed
                suites[idx].tests[j].failureMessage = "Assertion failed"
            } else {
                suites[idx].tests[j].status = .skipped
            }
            suites[idx].tests[j].durationMs = Double.random(in: 10...500)
            testOutput += "\(suites[idx].tests[j].status == .passed ? "PASS" : suites[idx].tests[j].status == .failed ? "FAIL" : "SKIP") \(suites[idx].name) > \(suites[idx].tests[j].name)\n"
        }
    }
}
