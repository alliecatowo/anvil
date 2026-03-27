import SwiftUI

// MARK: - Models

struct DatabaseTable: Identifiable {
    let id = UUID()
    let name: String
    let columns: [DatabaseColumn]
}

struct DatabaseColumn: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let constraint: String?
}

struct QueryResult: Identifiable {
    let id = UUID()
    let columns: [String]
    let rows: [[String]]
}

struct QueryHistoryEntry: Identifiable {
    let id = UUID()
    let sql: String
    let timestamp: Date
}

// MARK: - ViewModel

@MainActor
class DatabaseViewModel: ObservableObject {
    @Published var tables: [DatabaseTable] = []
    @Published var selectedTableId: UUID?
    @Published var expandedTableIds: Set<UUID> = []
    @Published var queryText: String = "SELECT * FROM users WHERE active = true;"
    @Published var queryResult: QueryResult?
    @Published var queryHistory: [QueryHistoryEntry] = []
    @Published var isRunningQuery: Bool = false
    @Published var currentPage: Int = 0
    let pageSize: Int = 20

    var selectedTable: DatabaseTable? {
        tables.first { $0.id == selectedTableId }
    }

    init() {
        tables = [
            DatabaseTable(name: "users", columns: [
                DatabaseColumn(name: "id", type: "SERIAL", constraint: "PRIMARY KEY"),
                DatabaseColumn(name: "email", type: "VARCHAR(255)", constraint: "UNIQUE NOT NULL"),
                DatabaseColumn(name: "name", type: "VARCHAR(128)", constraint: "NOT NULL"),
                DatabaseColumn(name: "active", type: "BOOLEAN", constraint: "DEFAULT true"),
                DatabaseColumn(name: "created_at", type: "TIMESTAMPTZ", constraint: "DEFAULT now()"),
            ]),
            DatabaseTable(name: "orders", columns: [
                DatabaseColumn(name: "id", type: "SERIAL", constraint: "PRIMARY KEY"),
                DatabaseColumn(name: "user_id", type: "INTEGER", constraint: "REFERENCES users(id)"),
                DatabaseColumn(name: "total", type: "NUMERIC(10,2)", constraint: "NOT NULL"),
                DatabaseColumn(name: "status", type: "VARCHAR(32)", constraint: "DEFAULT 'pending'"),
                DatabaseColumn(name: "ordered_at", type: "TIMESTAMPTZ", constraint: "DEFAULT now()"),
            ]),
            DatabaseTable(name: "products", columns: [
                DatabaseColumn(name: "id", type: "SERIAL", constraint: "PRIMARY KEY"),
                DatabaseColumn(name: "name", type: "VARCHAR(255)", constraint: "NOT NULL"),
                DatabaseColumn(name: "price", type: "NUMERIC(10,2)", constraint: "NOT NULL"),
                DatabaseColumn(name: "sku", type: "VARCHAR(64)", constraint: "UNIQUE"),
                DatabaseColumn(name: "in_stock", type: "BOOLEAN", constraint: "DEFAULT true"),
            ]),
        ]

        selectedTableId = tables.first?.id
        expandedTableIds = Set(tables.map(\.id))

        // Populate sample query result
        queryResult = QueryResult(
            columns: ["id", "email", "name", "active", "created_at"],
            rows: [
                ["1", "alice@example.com", "Alice Chen", "true", "2025-01-15 09:30:00"],
                ["2", "bob@example.com", "Bob Martinez", "true", "2025-02-20 14:12:00"],
                ["3", "carol@example.com", "Carol Nguyen", "false", "2025-03-01 08:45:00"],
                ["4", "dave@example.com", "Dave Johnson", "true", "2025-03-10 11:20:00"],
                ["5", "eve@example.com", "Eve Williams", "true", "2025-03-18 16:00:00"],
            ]
        )

        queryHistory = [
            QueryHistoryEntry(sql: "SELECT * FROM users WHERE active = true;", timestamp: Date()),
            QueryHistoryEntry(sql: "SELECT COUNT(*) FROM orders;", timestamp: Date().addingTimeInterval(-300)),
        ]
    }

    // MARK: - Actions

    func selectTable(_ id: UUID) {
        selectedTableId = id
    }

    func toggleTable(_ id: UUID) {
        if expandedTableIds.contains(id) {
            expandedTableIds.remove(id)
        } else {
            expandedTableIds.insert(id)
        }
    }

    func runQuery() {
        guard !queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isRunningQuery = true

        let entry = QueryHistoryEntry(sql: queryText, timestamp: Date())
        queryHistory.insert(entry, at: 0)

        // Simulate query execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isRunningQuery = false
        }
        currentPage = 0
    }

    func selectHistoryEntry(_ entry: QueryHistoryEntry) {
        queryText = entry.sql
    }
}
