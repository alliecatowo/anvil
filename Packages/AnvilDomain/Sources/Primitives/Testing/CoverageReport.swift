import Foundation

public struct CoverageReport: Sendable, Codable {
    public let totalLinesCovered: Int
    public let totalLinesTotal: Int
    public let coveragePercentage: Double
    public let files: [FileCoverage]
    public let generatedAt: Date

    public init(totalLinesCovered: Int, totalLinesTotal: Int, coveragePercentage: Double, files: [FileCoverage] = [], generatedAt: Date = .now) {
        self.totalLinesCovered = totalLinesCovered
        self.totalLinesTotal = totalLinesTotal
        self.coveragePercentage = coveragePercentage
        self.files = files
        self.generatedAt = generatedAt
    }
}

public struct FileCoverage: Sendable, Identifiable, Codable {
    public var id: String { filePath }
    public let filePath: String
    public let linesCovered: Int
    public let linesTotal: Int
    public let coveragePercentage: Double
    public let uncoveredLines: [Int]

    public init(filePath: String, linesCovered: Int, linesTotal: Int, coveragePercentage: Double, uncoveredLines: [Int] = []) {
        self.filePath = filePath
        self.linesCovered = linesCovered
        self.linesTotal = linesTotal
        self.coveragePercentage = coveragePercentage
        self.uncoveredLines = uncoveredLines
    }
}
