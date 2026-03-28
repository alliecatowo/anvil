import Foundation
import SwiftUI
import AnvilDomain
import AnvilApplication

// MARK: - Local UI Models

enum DatabaseObjectKind: String, CaseIterable {
    case table
    case view

    var label: String {
        switch self {
        case .table: "Tables"
        case .view: "Views"
        }
    }

    var symbolName: String {
        switch self {
        case .table: "tablecells"
        case .view: "rectangle.on.rectangle"
        }
    }
}

struct DatabaseTable: Identifiable {
    let id: String
    let name: String
    let columns: [DatabaseColumn]
    let primaryKeys: [String]
    let rowCount: Int?
}

struct DatabaseColumn: Identifiable {
    var id: String { "\(tableName).\(name)" }
    let tableName: String
    let name: String
    let type: String
    let isNullable: Bool
    let isPrimaryKey: Bool
    let defaultValue: String?
}

struct DatabaseObject: Identifiable {
    let kind: DatabaseObjectKind
    let name: String
    let columns: [DatabaseColumn]
    let rowCount: Int?

    var id: String { "\(kind.rawValue):\(name)" }
}

struct DatabaseProviderOption: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let connectionStyle: DatabaseConnectionStyle
    let supportedFileExtensions: [String]
    let notes: String?
}

struct QueryHistoryEntry: Identifiable {
    let id = UUID()
    let sql: String
    let timestamp: Date
    let executionTimeMs: Double?
    let rowCount: Int?
    let error: String?
}

struct DatabaseResultRow: Identifiable {
    let id: Int
    let values: [String]

    func value(at index: Int) -> String {
        guard values.indices.contains(index) else { return "" }
        return values[index]
    }
}

private enum DatabaseResultContext: Equatable {
    case object(name: String)
    case query
}

// MARK: - ViewModel

@MainActor
class DatabaseViewModel: ObservableObject {
    @Published var tables: [DatabaseTable] = []
    @Published var views: [DatabaseObject] = []
    @Published var selectedTableId: String?
    @Published var expandedTableIds: Set<String> = []
    @Published var queryText: String = ""
    @Published var queryResult: AnvilDomain.QueryResult?
    @Published var queryHistory: [QueryHistoryEntry] = []
    @Published var isRunningQuery: Bool = false
    @Published var isConnected: Bool = false
    @Published var connectionPath: String = ""
    @Published var errorMessage: String?
    @Published var databaseName: String = ""
    @Published var availableProviders: [DatabaseProviderOption] = []
    @Published var selectedProviderId: String?

    @Published var currentPage: Int = 0
    @Published var totalRowCount: Int = 0
    let pageSize: Int = 50

    @Published var sortColumn: String?
    @Published var sortAscending: Bool = true

    private weak var databaseService: DatabaseService?
    private var resultContext: DatabaseResultContext?

    var selectedProvider: DatabaseProviderOption? {
        availableProviders.first { $0.id == selectedProviderId }
    }

    var selectedObject: DatabaseObject? {
        if let table = tables.first(where: { $0.id == selectedTableId }) {
            return DatabaseObject(kind: .table, name: table.name, columns: table.columns, rowCount: table.rowCount)
        }
        return views.first(where: { $0.name == selectedTableId })
    }

    var connectionTitle: String {
        if let activeConnection = databaseService?.activeConnection {
            return activeConnection.name
        }
        return databaseName.isEmpty ? "Database" : databaseName
    }

    var connectionSubtitle: String {
        databaseService?.activeConnection?.configuration.displayLocation ?? connectionPath
    }

    var totalPages: Int {
        guard totalRowCount > 0 else { return 1 }
        return max(1, (totalRowCount + pageSize - 1) / pageSize)
    }

    var resultRows: [DatabaseResultRow] {
        guard let queryResult else { return [] }
        return queryResult.rows.enumerated().map { index, row in
            DatabaseResultRow(id: index, values: row)
        }
    }

    var canExportResults: Bool {
        guard let queryResult else { return false }
        return !queryResult.columns.isEmpty
    }

    var canSortCurrentResults: Bool {
        if case .object = resultContext { return queryResult?.columns.isEmpty == false }
        return false
    }

    var sortableColumns: [String] {
        queryResult?.columns ?? selectedObject?.columns.map(\.name) ?? []
    }

    func configure(service: DatabaseService) {
        databaseService = service
        availableProviders = service.availableProviders.map(Self.providerOption(from:))
        selectedProviderId = selectedProviderId ?? availableProviders.first?.id
        syncConnectionState()
    }

    // MARK: - Connection

    func connect(path: String) async {
        connectionPath = path
        await connectCurrentProvider()
    }

    func connectCurrentProvider() async {
        guard let service = databaseService else {
            errorMessage = "Database service not configured"
            return
        }
        guard let provider = selectedProvider else {
            errorMessage = "No database provider configured"
            return
        }

        switch provider.connectionStyle {
        case .file:
            let trimmedPath = connectionPath.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else {
                errorMessage = "Choose a database file"
                return
            }

            let connection = DatabaseConnection(
                name: URL(fileURLWithPath: trimmedPath).lastPathComponent,
                providerId: provider.id,
                providerKind: providerKind(for: provider.id),
                configuration: .sqlite(filePath: trimmedPath)
            )
            await service.connect(connection)
        case .server:
            errorMessage = "\(provider.title) server connections are not wired yet"
            return
        }

        availableProviders = service.availableProviders.map(Self.providerOption(from:))
        syncConnectionState()
        if isConnected {
            await loadSchema()
        }
    }

    func disconnect() async {
        guard let service = databaseService else { return }
        await service.disconnect()
        clearConnectionState()
        errorMessage = nil
    }

    // MARK: - Schema

    func loadSchema() async {
        guard let service = databaseService else { return }
        await service.refreshSchema()
        syncConnectionState()

        guard let schema = service.currentSchema else { return }
        databaseName = schema.databaseName

        tables = schema.tables.map { definition in
            DatabaseTable(
                id: definition.name,
                name: definition.name,
                columns: definition.columns.map { column in
                    DatabaseColumn(
                        tableName: definition.name,
                        name: column.name,
                        type: column.dataType,
                        isNullable: column.isNullable,
                        isPrimaryKey: definition.primaryKey.contains(column.name),
                        defaultValue: column.defaultValue
                    )
                },
                primaryKeys: definition.primaryKey,
                rowCount: definition.rowCount
            )
        }

        views = schema.views.map { name in
            DatabaseObject(kind: .view, name: name, columns: [], rowCount: nil)
        }

        if selectedTableId == nil {
            expandedTableIds = Set(tables.map(\.id))
            if let firstTable = tables.first {
                await selectObject(named: firstTable.id)
            } else if let firstView = views.first {
                await selectObject(named: firstView.name)
            }
        }
    }

    func refreshSchema() async {
        await loadSchema()
    }

    // MARK: - Selection

    func selectTable(_ id: String) {
        prepareForObjectSelection(named: id)
        Task { await browseSelectedObject() }
    }

    func selectView(_ name: String) {
        prepareForObjectSelection(named: name)
        Task { await browseSelectedObject() }
    }

    func toggleTable(_ id: String) {
        if expandedTableIds.contains(id) {
            expandedTableIds.remove(id)
        } else {
            expandedTableIds.insert(id)
        }
    }

    func selectHistoryEntry(_ entry: QueryHistoryEntry) {
        queryText = entry.sql
    }

    func clearResults() {
        queryResult = nil
        totalRowCount = 0
        currentPage = 0
        sortColumn = nil
        sortAscending = true
        resultContext = nil
    }

    func resetEditor() {
        queryText = ""
        errorMessage = nil
    }

    // MARK: - Actions

    func runQuery() {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty else { return }
        isRunningQuery = true
        errorMessage = nil

        Task {
            guard let service = databaseService else {
                isRunningQuery = false
                errorMessage = "Not connected"
                return
            }

            if let result = await service.executeQuery(sql) {
                queryResult = result
                totalRowCount = result.rows.count
                currentPage = 0
                resultContext = .query
                recordHistory(sql: sql, result: result, error: nil)
            } else {
                let error = service.lastError ?? "Unknown error"
                errorMessage = error
                recordHistory(sql: sql, result: nil, error: error)
            }

            isRunningQuery = false
        }
    }

    func rerun(_ entry: QueryHistoryEntry) {
        queryText = entry.sql
        runQuery()
    }

    func browseSelectedTable() async {
        await browseSelectedObject()
    }

    func browseSelectedObject() async {
        guard let selectedObject,
              let service = databaseService else { return }

        let offset = currentPage * pageSize
        let request = DatabaseBrowseRequest(
            objectName: selectedObject.name,
            limit: pageSize,
            offset: offset,
            sortColumn: sortColumn,
            sortAscending: sortAscending
        )

        if let countResult = await service.executeQuery("SELECT COUNT(*) FROM \"\(selectedObject.name)\";"),
           let countValue = countResult.rows.first?.first,
           let count = Int(countValue) {
            totalRowCount = count
        } else {
            totalRowCount = 0
        }

        if let result = await service.browse(request) {
            queryResult = result
            errorMessage = nil
            resultContext = .object(name: selectedObject.name)
        } else {
            errorMessage = service.lastError
        }
    }

    func nextPage() {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 1
        Task { await browseSelectedObject() }
    }

    func previousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
        Task { await browseSelectedObject() }
    }

    func sortBy(column: String) {
        guard canSortCurrentResults else { return }
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = true
        }
        currentPage = 0
        Task { await browseSelectedObject() }
    }

    func exportResults(to url: URL) throws {
        guard let queryResult else { return }
        let csv = csv(for: queryResult)
        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Private

    private func syncConnectionState() {
        guard let service = databaseService else { return }
        isConnected = service.isConnected
        errorMessage = service.lastError
        if let activeConnection = service.activeConnection {
            connectionPath = activeConnection.configuration.filePath ?? activeConnection.configuration.displayLocation
            databaseName = service.currentSchema?.databaseName ?? activeConnection.configuration.databaseName
            selectedProviderId = activeConnection.providerId
        }
    }

    private func clearConnectionState() {
        isConnected = false
        connectionPath = ""
        databaseName = ""
        tables = []
        views = []
        selectedTableId = nil
        expandedTableIds = []
        clearResults()
    }

    private func selectObject(named name: String) async {
        prepareForObjectSelection(named: name)
        await browseSelectedObject()
    }

    private func prepareForObjectSelection(named name: String) {
        selectedTableId = name
        currentPage = 0
        sortColumn = nil
        sortAscending = true
    }

    private func recordHistory(sql: String, result: AnvilDomain.QueryResult?, error: String?) {
        queryHistory.insert(
            QueryHistoryEntry(
                sql: sql,
                timestamp: Date(),
                executionTimeMs: result?.executionTimeMs,
                rowCount: result?.rows.count,
                error: error
            ),
            at: 0
        )

        if queryHistory.count > 100 {
            queryHistory = Array(queryHistory.prefix(100))
        }
    }

    private func providerKind(for providerId: String) -> DatabaseProviderKind {
        databaseService?.availableProviders.first(where: { $0.id == providerId })?.kind ?? .sqlite
    }

    private func csv(for result: AnvilDomain.QueryResult) -> String {
        let lines = [result.columns] + result.rows
        return lines
            .map { row in row.map(csvField).joined(separator: ",") }
            .joined(separator: "\n")
    }

    private func csvField(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func providerOption(from descriptor: DatabaseProviderDescriptor) -> DatabaseProviderOption {
        DatabaseProviderOption(
            id: descriptor.id,
            title: descriptor.displayName,
            summary: descriptor.kind == .sqlite ? "Local file-backed database" : descriptor.kind.displayName,
            connectionStyle: descriptor.connectionStyle,
            supportedFileExtensions: descriptor.supportedFileExtensions,
            notes: descriptor.notes
        )
    }
}
