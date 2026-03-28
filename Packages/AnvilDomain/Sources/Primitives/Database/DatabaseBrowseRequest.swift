import Foundation

public struct DatabaseBrowseRequest: Sendable, Codable, Equatable {
    public let objectName: String
    public let limit: Int
    public let offset: Int
    public let sortColumn: String?
    public let sortAscending: Bool

    public init(
        objectName: String,
        limit: Int = 50,
        offset: Int = 0,
        sortColumn: String? = nil,
        sortAscending: Bool = true
    ) {
        self.objectName = objectName
        self.limit = limit
        self.offset = offset
        self.sortColumn = sortColumn
        self.sortAscending = sortAscending
    }
}
