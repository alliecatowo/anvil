import Foundation

public protocol TestingPort: AnvilProviderDefinition {
    func discover(projectPath: String) async throws -> [TestSuite]
    func runAll(projectPath: String) async throws -> [TestSuiteResult]
    func runSuite(projectPath: String, suiteName: String) async throws -> TestSuiteResult
    func runCase(projectPath: String, suiteName: String, caseName: String) async throws -> TestCaseResult
    func coverage(projectPath: String) async throws -> CoverageReport
    func watch(projectPath: String) async throws -> AsyncThrowingStream<TestSuiteResult, Error>
}
