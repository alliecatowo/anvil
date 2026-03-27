import Foundation

public struct QueryResult: Sendable, Codable {
    public let columns: [String]
    public let rows: [[String]]
    public let rowsAffected: Int
    public let executionTimeMs: Double

    public init(columns: [String] = [], rows: [[String]] = [], rowsAffected: Int = 0, executionTimeMs: Double = 0) {
        self.columns = columns
        self.rows = rows
        self.rowsAffected = rowsAffected
        self.executionTimeMs = executionTimeMs
    }
}
