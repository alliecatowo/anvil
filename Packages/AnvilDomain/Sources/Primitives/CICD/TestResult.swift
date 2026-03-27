import Foundation

public struct TestResult: Sendable, Identifiable, Codable {
    public let id: String
    public let runId: String
    public let suiteName: String
    public let testName: String
    public let status: TestResultStatus
    public let durationMs: Double
    public let failureMessage: String?

    public init(id: String = UUID().uuidString, runId: String, suiteName: String, testName: String, status: TestResultStatus, durationMs: Double = 0, failureMessage: String? = nil) {
        self.id = id
        self.runId = runId
        self.suiteName = suiteName
        self.testName = testName
        self.status = status
        self.durationMs = durationMs
        self.failureMessage = failureMessage
    }
}

public enum TestResultStatus: String, Sendable, Codable {
    case passed, failed, skipped, errored
}
