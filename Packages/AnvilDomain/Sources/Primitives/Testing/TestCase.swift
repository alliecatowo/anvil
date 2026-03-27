import Foundation

public struct TestCase: Sendable, Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let suiteName: String
    public let isEnabled: Bool

    public init(name: String, suiteName: String, isEnabled: Bool = true) {
        self.name = name
        self.suiteName = suiteName
        self.isEnabled = isEnabled
    }
}

public struct TestCaseResult: Sendable, Identifiable, Codable {
    public let id: String
    public let caseName: String
    public let status: TestCaseStatus
    public let durationMs: Double
    public let failureMessage: String?
    public let failureLocation: String?

    public init(id: String = UUID().uuidString, caseName: String, status: TestCaseStatus, durationMs: Double = 0, failureMessage: String? = nil, failureLocation: String? = nil) {
        self.id = id
        self.caseName = caseName
        self.status = status
        self.durationMs = durationMs
        self.failureMessage = failureMessage
        self.failureLocation = failureLocation
    }
}

public enum TestCaseStatus: String, Sendable, Codable {
    case passed, failed, skipped, errored
}
