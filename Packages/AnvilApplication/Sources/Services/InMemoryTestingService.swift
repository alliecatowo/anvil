import AnvilDomain
import Foundation

/// In-memory testing store -- default implementation until a real test runner is wired.
public actor InMemoryTestingService: TestingPort {
    private var suites: [String: TestSuite] = [:]
    private var results: [String: TestSuiteResult] = [:]  // keyed by suite name

    public let providerId = "in-memory-testing"
    public let providerName = "In-Memory Testing"

    public init() {
        let unit = TestSuite(name: "UnitTests", filePath: "Tests/UnitTests.swift", cases: [
            TestCase(name: "testExample", suiteName: "UnitTests"),
            TestCase(name: "testAnother", suiteName: "UnitTests"),
        ])
        let integration = TestSuite(name: "IntegrationTests", filePath: "Tests/IntegrationTests.swift", cases: [
            TestCase(name: "testEndToEnd", suiteName: "IntegrationTests"),
        ])
        suites[unit.name] = unit
        suites[integration.name] = integration
    }

    public func validateConnection() async throws -> Bool { true }

    public func discover(projectPath: String) async throws -> [TestSuite] {
        Array(suites.values).sorted { $0.name < $1.name }
    }

    public func runAll(projectPath: String) async throws -> [TestSuiteResult] {
        var allResults: [TestSuiteResult] = []
        for suite in suites.values {
            let result = makeSuiteResult(for: suite)
            results[suite.name] = result
            allResults.append(result)
        }
        return allResults
    }

    public func runSuite(projectPath: String, suiteName: String) async throws -> TestSuiteResult {
        guard let suite = suites[suiteName] else { throw TestingServiceError.notFound }
        let result = makeSuiteResult(for: suite)
        results[suiteName] = result
        return result
    }

    public func runCase(projectPath: String, suiteName: String, caseName: String) async throws -> TestCaseResult {
        guard let suite = suites[suiteName] else { throw TestingServiceError.notFound }
        guard suite.cases.contains(where: { $0.name == caseName }) else { throw TestingServiceError.notFound }
        return TestCaseResult(caseName: caseName, status: .passed, durationMs: 12.0)
    }

    public func coverage(projectPath: String) async throws -> CoverageReport {
        CoverageReport(totalLinesCovered: 420, totalLinesTotal: 600, coveragePercentage: 70.0)
    }

    public func watch(projectPath: String) async throws -> AsyncThrowingStream<TestSuiteResult, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    // MARK: - Helpers

    private func makeSuiteResult(for suite: TestSuite) -> TestSuiteResult {
        let caseResults = suite.cases.map {
            TestCaseResult(caseName: $0.name, status: .passed, durationMs: 8.5)
        }
        return TestSuiteResult(
            suiteName: suite.name,
            passed: caseResults.count,
            failed: 0,
            skipped: 0,
            durationMs: Double(caseResults.count) * 8.5,
            caseResults: caseResults
        )
    }
}

public enum TestingServiceError: Error, Sendable {
    case notFound
}
