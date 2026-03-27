import Foundation

public struct Schema: Sendable, Codable {
    public let tables: [TableDefinition]
    public let views: [String]
    public let databaseName: String

    public init(tables: [TableDefinition], views: [String] = [], databaseName: String) {
        self.tables = tables
        self.views = views
        self.databaseName = databaseName
    }
}

public struct TableDefinition: Sendable, Identifiable, Codable {
    public var id: String { name }
    public let name: String
    public let columns: [ColumnDefinition]
    public let primaryKey: [String]
    public let rowCount: Int?

    public init(name: String, columns: [ColumnDefinition], primaryKey: [String] = [], rowCount: Int? = nil) {
        self.name = name
        self.columns = columns
        self.primaryKey = primaryKey
        self.rowCount = rowCount
    }
}

public struct ColumnDefinition: Sendable, Codable {
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let defaultValue: String?

    public init(name: String, dataType: String, isNullable: Bool = true, defaultValue: String? = nil) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.defaultValue = defaultValue
    }
}
