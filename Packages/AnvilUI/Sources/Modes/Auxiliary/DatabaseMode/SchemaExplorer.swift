import SwiftUI

struct SchemaExplorer: View {
    @ObservedObject var viewModel: DatabaseViewModel
    let onExportResults: () -> Void

    @State private var showsTables = true
    @State private var showsViews = true
    @State private var showsHistory = true

    var body: some View {
        List {
            connectionSection
            objectsSection
            historySection
            actionsSection
        }
        .listStyle(.sidebar)
    }

    private var connectionSection: some View {
        Section("Connection") {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.connectionTitle)
                    .font(.headline)

                if !viewModel.connectionSubtitle.isEmpty {
                    Text(viewModel.connectionSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .padding(.vertical, 4)

            Button {
                Task { await viewModel.refreshSchema() }
            } label: {
                Label("Refresh Schema", systemImage: "arrow.clockwise")
            }

            Button(role: .destructive) {
                Task { await viewModel.disconnect() }
            } label: {
                Label("Disconnect", systemImage: "eject.fill")
            }
        }
    }

    private var objectsSection: some View {
        Section("Objects") {
            DisclosureGroup(isExpanded: $showsTables) {
                if viewModel.tables.isEmpty {
                    Text("No tables")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.tables) { table in
                        objectRow(
                            title: table.name,
                            subtitle: table.rowCount.map { "\($0) rows" } ?? "\(table.columns.count) columns",
                            systemImage: "tablecells",
                            isSelected: viewModel.selectedTableId == table.id
                        ) {
                            viewModel.selectTable(table.id)
                        }
                    }
                }
            } label: {
                Label("Tables", systemImage: "tablecells")
            }

            DisclosureGroup(isExpanded: $showsViews) {
                if viewModel.views.isEmpty {
                    Text("No views")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.views) { view in
                        objectRow(
                            title: view.name,
                            subtitle: "Query view",
                            systemImage: "rectangle.on.rectangle",
                            isSelected: viewModel.selectedTableId == view.name
                        ) {
                            viewModel.selectView(view.name)
                        }
                    }
                }
            } label: {
                Label("Views", systemImage: "rectangle.on.rectangle")
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            DisclosureGroup(isExpanded: $showsHistory) {
                if viewModel.queryHistory.isEmpty {
                    Text("No queries run yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.queryHistory.prefix(20)) { entry in
                        Button {
                            viewModel.rerun(entry)
                        } label: {
                            historyRow(entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Load Into Editor") {
                                viewModel.selectHistoryEntry(entry)
                            }
                            Button("Run Again") {
                                viewModel.rerun(entry)
                            }
                        }
                    }
                }
            } label: {
                Label("Recent Queries", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button {
                viewModel.resetEditor()
            } label: {
                Label("New Query", systemImage: "square.and.pencil")
            }

            Button {
                viewModel.clearResults()
            } label: {
                Label("Clear Results", systemImage: "trash")
            }
            .disabled(viewModel.queryResult == nil)

            if viewModel.canExportResults {
                Button {
                    onExportResults()
                } label: {
                    Label("Export CSV…", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private func objectRow(
        title: String,
        subtitle: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }

    private func historyRow(_ entry: QueryHistoryEntry) -> some View {
        let displaySQL = entry.sql.replacingOccurrences(of: "\n", with: " ")
        let textColor: Color = entry.error == nil ? .primary : .red

        return VStack(alignment: .leading, spacing: 4) {
            Text(displaySQL)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2)
                .foregroundStyle(textColor)

            HStack(spacing: 8) {
                if let rowCount = entry.rowCount {
                    Text("\(rowCount) rows")
                }
                if let executionTimeMs = entry.executionTimeMs {
                    Text(String(format: "%.1f ms", executionTimeMs))
                }
                Text(entry.timestamp, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
