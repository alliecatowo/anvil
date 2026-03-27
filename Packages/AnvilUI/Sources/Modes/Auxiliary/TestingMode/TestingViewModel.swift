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
        isRunning = true
        testOutput = "Running all tests...\n"

        // Simulate: mark everything as running, then complete after delay
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

    public func runSuite(_ suiteId: String) {
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

    public func runTest(_ testId: String) {
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

    public func toggleSuiteExpansion(_ suiteId: String) {
        if let idx = suites.firstIndex(where: { $0.id == suiteId }) {
            suites[idx].isExpanded.toggle()
        }
    }

    // MARK: - Demo Data

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
