import Foundation

public struct Board: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let columns: [BoardColumn]

    public init(id: String = UUID().uuidString, name: String, columns: [BoardColumn]) {
        self.id = id
        self.name = name
        self.columns = columns
    }
}

public struct BoardColumn: Sendable, Identifiable, Codable {
    public let id: String
    public let name: String
    public let status: String
    public let wipLimit: Int?

    public init(id: String = UUID().uuidString, name: String, status: String, wipLimit: Int? = nil) {
        self.id = id
        self.name = name
        self.status = status
        self.wipLimit = wipLimit
    }
}
