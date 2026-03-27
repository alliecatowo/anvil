import Foundation

public struct TestSuite: Sendable, Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let filePath: String
    public let cases: [TestCase]

    public init(name: String, filePath: String, cases: [TestCase] = []) {
        self.name = name
        self.filePath = filePath
        self.cases = cases
    }
}

public struct TestSuiteResult: Sendable, Identifiable, Codable {
    public let id: String
    public let suiteName: String
    public let passed: Int
    public let failed: Int
    public let skipped: Int
    public let durationMs: Double
    public let caseResults: [TestCaseResult]

    public init(id: String = UUID().uuidString, suiteName: String, passed: Int = 0, failed: Int = 0, skipped: Int = 0, durationMs: Double = 0, caseResults: [TestCaseResult] = []) {
        self.id = id
        self.suiteName = suiteName
        self.passed = passed
        self.failed = failed
        self.skipped = skipped
        self.durationMs = durationMs
        self.caseResults = caseResults
    }
}
