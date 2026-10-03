import XCTest
@testable import AnvilUI
import AnvilDomain
import AnvilApplication

// MARK: - Mock DatabasePort

/// A controllable in-memory database adapter for testing.
final class MockDatabasePort: DatabasePort, @unchecked Sendable {
    let providerId: String = "sqlite-local"
    let providerName: String = "SQLite"
    let providerKind: DatabaseProviderKind = .sqlite
    let descriptor = DatabaseProviderDescriptor(
        id: "sqlite-local",
        displayName: "SQLite",
        kind: .sqlite,
        connectionStyle: .file,
        supportedFileExtensions: ["sqlite", "db", "sqlite3"],
        capabilities: [.connect, .inspectSchema, .browseObjects, .executeQueries]
    )

    // Injected responses
    var shouldConnect: Bool = true
    var connectError: Error?
    var schemaToReturn: Schema?
    var queryResultToReturn: QueryResult?
    var queryError: Error?
    var tables: [String] = []

    var connectCallCount = 0
    var disconnectCallCount = 0
    var lastExecutedSQL: String?

    func validateConnection() async throws -> Bool { true }

    func connect(connection: DatabaseConnection) async throws -> DatabaseConnection {
        connectCallCount += 1
        if let err = connectError { throw err }
        if !shouldConnect { throw MockError.connectionFailed }
        return DatabaseConnection(
            id: connection.id,
            name: connection.name,
            providerId: providerId,
            providerKind: .sqlite,
            configuration: connection.configuration,
            isConnected: true
        )
    }

    func connect(connectionId: String) async throws {
        connectCallCount += 1
        if let err = connectError { throw err }
        if !shouldConnect { throw MockError.connectionFailed }
    }

    func disconnect(connectionId: String) async throws {
        disconnectCallCount += 1
    }

    func schema(connectionId: String) async throws -> Schema {
        if let schema = schemaToReturn { return schema }
        return Schema(tables: [], databaseName: "test.db")
    }

    func execute(connectionId: String, query: String) async throws -> QueryResult {
        lastExecutedSQL = query
        if let err = queryError { throw err }
        return queryResultToReturn ?? QueryResult(columns: [], rows: [], rowsAffected: 0, executionTimeMs: 1.0)
    }

    func browse(connectionId: String, request: DatabaseBrowseRequest) async throws -> QueryResult {
        lastExecutedSQL = "BROWSE \(request.objectName)"
        if let err = queryError { throw err }
        return queryResultToReturn ?? QueryResult(columns: [], rows: [], rowsAffected: 0, executionTimeMs: 1.0)
    }

    func tables(connectionId: String) async throws -> [String] {
        return tables
    }

    func migrations(directory: String) async throws -> [Migration] { [] }
    func runMigration(connectionId: String, migration: Migration) async throws {}
    func rollbackMigration(connectionId: String, migration: Migration) async throws {}

    enum MockError: Error {
        case connectionFailed
        case queryFailed
    }
}

// MARK: - Tests

@MainActor
final class DatabaseViewModelTests: XCTestCase {

    // MARK: - Init

    func testInitHasNoTables() {
        let vm = DatabaseViewModel()
        XCTAssertTrue(vm.tables.isEmpty, "DatabaseViewModel must start with no tables")
    }

    func testInitIsNotConnected() {
        let vm = DatabaseViewModel()
        XCTAssertFalse(vm.isConnected, "DatabaseViewModel must not be connected on init")
    }

    func testInitHasEmptyQueryText() {
        let vm = DatabaseViewModel()
        XCTAssertTrue(vm.queryText.isEmpty, "queryText must be empty on init")
    }

    func testInitHasNoQueryResult() {
        let vm = DatabaseViewModel()
        XCTAssertNil(vm.queryResult, "queryResult must be nil on init")
    }

    func testInitHasEmptyQueryHistory() {
        let vm = DatabaseViewModel()
        XCTAssertTrue(vm.queryHistory.isEmpty, "queryHistory must be empty on init")
    }

    func testInitIsNotRunningQuery() {
        let vm = DatabaseViewModel()
        XCTAssertFalse(vm.isRunningQuery, "isRunningQuery must be false on init")
    }

    func testInitPageZero() {
        let vm = DatabaseViewModel()
        XCTAssertEqual(vm.currentPage, 0, "currentPage must start at 0")
    }

    func testInitSortAscending() {
        let vm = DatabaseViewModel()
        XCTAssertTrue(vm.sortAscending, "sortAscending must default to true")
    }

    // MARK: - configure + connect (with mock)

    func testConnectSuccessMarksConnected() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        service.setAdapter(mock)
        vm.configure(service: service)

        await vm.connect(path: "/tmp/test.db")

        XCTAssertTrue(vm.isConnected, "connect must mark isConnected true on success")
    }

    func testConnectSetsConnectionPath() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        service.setAdapter(mock)
        vm.configure(service: service)

        await vm.connect(path: "/tmp/test.db")

        XCTAssertEqual(vm.connectionPath, "/tmp/test.db", "connect must store the connection path")
    }

    func testConnectFailureMarksNotConnected() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        mock.shouldConnect = false
        service.setAdapter(mock)
        vm.configure(service: service)

        await vm.connect(path: "/tmp/bad.db")

        XCTAssertFalse(vm.isConnected, "Failed connect must leave isConnected false")
    }

    func testConnectWithoutServiceSetsError() async {
        let vm = DatabaseViewModel()
        // No service configured
        await vm.connect(path: "/tmp/test.db")
        XCTAssertNotNil(vm.errorMessage, "connect without configured service must set errorMessage")
    }

    func testConnectLoadsSchema() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        let schema = Schema(
            tables: [
                TableDefinition(name: "users", columns: [
                    ColumnDefinition(name: "id", dataType: "INTEGER", isNullable: false),
                    ColumnDefinition(name: "email", dataType: "TEXT", isNullable: false),
                ], primaryKey: ["id"], rowCount: 42)
            ],
            databaseName: "app.db"
        )
        mock.schemaToReturn = schema
        // executeQuery must also return something for COUNT
        mock.queryResultToReturn = QueryResult(columns: ["COUNT(*)"], rows: [["42"]], rowsAffected: 0, executionTimeMs: 1)
        service.setAdapter(mock)
        vm.configure(service: service)

        await vm.connect(path: "/tmp/app.db")

        XCTAssertEqual(vm.tables.count, 1, "connect must load schema tables")
        XCTAssertEqual(vm.tables.first?.name, "users", "connect must load correct table names")
    }

    func testConnectSetsDatabaseName() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        let schema = Schema(tables: [], databaseName: "my_app.db")
        mock.schemaToReturn = schema
        service.setAdapter(mock)
        vm.configure(service: service)

        await vm.connect(path: "/tmp/my_app.db")

        XCTAssertEqual(vm.databaseName, "my_app.db", "connect must set databaseName from schema")
    }

    // MARK: - disconnect

    func testDisconnectClearsState() async {
        let vm = DatabaseViewModel()
        let service = DatabaseService()
        let mock = MockDatabasePort()
        service.setAdapter(mock)
        vm.configure(service: service)
        await vm.connect(path: "/tmp/test.db")

        await vm.disconnect()

        XCTAssertFalse(vm.isConnected, "disconnect must set isConnected to false")
        XCTAssertTrue(vm.tables.isEmpty, "disconnect must clear tables")
        XCTAssertNil(vm.selectedTableId, "disconnect must clear selectedTableId")
        XCTAssertNil(vm.queryResult, "disconnect must clear queryResult")
        XCTAssertTrue(vm.databaseName.isEmpty, "disconnect must clear databaseName")
    }

    // MARK: - selectTable

    func testSelectTableUpdatesSelectedId() {
        let vm = DatabaseViewModel()
        vm.tables = [
            DatabaseTable(id: "users", name: "users", columns: [], primaryKeys: [], rowCount: nil)
        ]
        vm.selectTable("users")
        XCTAssertEqual(vm.selectedTableId, "users", "selectTable must update selectedTableId")
    }

    func testSelectTableResetsPagination() {
        let vm = DatabaseViewModel()
        vm.currentPage = 5
        vm.tables = [DatabaseTable(id: "users", name: "users", columns: [], primaryKeys: [], rowCount: nil)]
        vm.selectTable("users")
        XCTAssertEqual(vm.currentPage, 0, "selectTable must reset currentPage to 0")
    }

    func testSelectTableResetsSortColumn() {
        let vm = DatabaseViewModel()
        vm.sortColumn = "email"
        vm.sortAscending = false
        vm.tables = [DatabaseTable(id: "users", name: "users", columns: [], primaryKeys: [], rowCount: nil)]
        vm.selectTable("users")
        XCTAssertNil(vm.sortColumn, "selectTable must clear sortColumn")
        XCTAssertTrue(vm.sortAscending, "selectTable must reset sortAscending to true")
    }

    // MARK: - toggleTable

    func testToggleTableExpandsWhenCollapsed() {
        let vm = DatabaseViewModel()
        vm.expandedTableIds = []
        vm.toggleTable("users")
        XCTAssertTrue(vm.expandedTableIds.contains("users"), "toggleTable must expand a collapsed table")
    }

    func testToggleTableCollapsesWhenExpanded() {
        let vm = DatabaseViewModel()
        vm.expandedTableIds = ["users"]
        vm.toggleTable("users")
        XCTAssertFalse(vm.expandedTableIds.contains("users"), "toggleTable must collapse an expanded table")
    }

    // MARK: - runQuery (state management, not actual DB)

    func testRunQueryIgnoresEmptyInput() {
        let vm = DatabaseViewModel()
        vm.queryText = "   "
        vm.runQuery()
        XCTAssertFalse(vm.isRunningQuery, "runQuery must ignore whitespace-only queryText")
    }

    // MARK: - selectHistoryEntry

    func testSelectHistoryEntryPopulatesQueryText() {
        let vm = DatabaseViewModel()
        let entry = QueryHistoryEntry(sql: "SELECT * FROM users", timestamp: Date(), executionTimeMs: 5.0, rowCount: 10, error: nil)
        vm.selectHistoryEntry(entry)
        XCTAssertEqual(vm.queryText, "SELECT * FROM users",
            "selectHistoryEntry must populate queryText with the historical SQL")
    }

    // MARK: - sortBy

    func testSortByNewColumnSetsAscending() {
        let vm = DatabaseViewModel()
        vm.sortColumn = nil
        vm.sortBy(column: "name")
        XCTAssertEqual(vm.sortColumn, "name", "sortBy must set sortColumn")
        XCTAssertTrue(vm.sortAscending, "First sort on a column must be ascending")
    }

    func testSortBySameColumnTogglesSortDirection() {
        let vm = DatabaseViewModel()
        vm.sortColumn = "name"
        vm.sortAscending = true
        vm.sortBy(column: "name")
        XCTAssertFalse(vm.sortAscending, "sortBy same column must toggle to descending")
    }

    func testSortBySameColumnDescendingTogglesAscending() {
        let vm = DatabaseViewModel()
        vm.sortColumn = "name"
        vm.sortAscending = false
        vm.sortBy(column: "name")
        XCTAssertTrue(vm.sortAscending, "sortBy same column descending must toggle to ascending")
    }

    func testSortByNewColumnResetsPagination() {
        let vm = DatabaseViewModel()
        vm.currentPage = 3
        vm.sortBy(column: "email")
        XCTAssertEqual(vm.currentPage, 0, "sortBy must reset currentPage to 0")
    }

    // MARK: - Pagination helpers

    func testTotalPagesIsOneForEmptyResult() {
        let vm = DatabaseViewModel()
        vm.totalRowCount = 0
        XCTAssertEqual(vm.totalPages, 1, "totalPages must be 1 when no rows")
    }

    func testTotalPagesCalculatedCorrectly() {
        let vm = DatabaseViewModel()
        vm.totalRowCount = 125 // 50 per page → 3 pages
        XCTAssertEqual(vm.totalPages, 3, "totalPages must be ceiling(rowCount / pageSize)")
    }

    func testTotalPagesExactMultiple() {
        let vm = DatabaseViewModel()
        vm.totalRowCount = 100 // exactly 2 pages of 50
        XCTAssertEqual(vm.totalPages, 2)
    }

    func testSelectedTableComputedProperty() {
        let vm = DatabaseViewModel()
        let table = DatabaseTable(id: "products", name: "products", columns: [], primaryKeys: [], rowCount: 10)
        vm.tables = [table]
        vm.selectedTableId = "products"
        XCTAssertEqual(vm.selectedTable?.name, "products", "selectedTable must return table matching selectedTableId")
    }

    func testSelectedTableNilWhenNoSelection() {
        let vm = DatabaseViewModel()
        vm.tables = [DatabaseTable(id: "t", name: "t", columns: [], primaryKeys: [], rowCount: nil)]
        vm.selectedTableId = nil
        XCTAssertNil(vm.selectedTable, "selectedTable must be nil when selectedTableId is nil")
    }
}
