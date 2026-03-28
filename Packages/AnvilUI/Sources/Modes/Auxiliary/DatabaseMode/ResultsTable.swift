import SwiftUI
import AnvilDomain

struct ResultsTable: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Results")
                        .font(.headline)

                    if let queryResult = viewModel.queryResult {
                        Text(summary(for: queryResult))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if viewModel.totalPages > 1 {
                    HStack(spacing: 10) {
                        Button {
                            viewModel.previousPage()
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(viewModel.currentPage == 0)

                        Text("Page \(viewModel.currentPage + 1) of \(viewModel.totalPages)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            viewModel.nextPage()
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(viewModel.currentPage >= viewModel.totalPages - 1)
                    }
                }
            }

            if let queryResult = viewModel.queryResult, !queryResult.columns.isEmpty {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow(columns: queryResult.columns)

                        Divider()

                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(viewModel.resultRows) { row in
                                resultRow(row: row, columnCount: queryResult.columns.count)
                                Divider()
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.quaternary.opacity(0.2))
                    )
                }
            } else {
                ContentUnavailableView(
                    "No Results Yet",
                    systemImage: "tablecells",
                    description: Text("Browse an object or run a query to inspect live data.")
                )
            }
        }
    }

    private func headerRow(columns: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                Text(column)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                if index < columns.count - 1 {
                    Divider()
                }
            }
        }
        .background(.thinMaterial)
    }

    private func resultRow(row: DatabaseResultRow, columnCount: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<columnCount, id: \.self) { index in
                let value = row.value(at: index)

                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(color(for: value))
                    .frame(width: columnWidth, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .textSelection(.enabled)

                if index < columnCount - 1 {
                    Divider()
                }
            }
        }
    }

    private func summary(for result: QueryResult) -> String {
        let visibleCount = result.rows.count
        let totalCount = viewModel.totalRowCount > 0 ? viewModel.totalRowCount : visibleCount

        if result.rowsAffected > 0, result.columns.isEmpty {
            return "\(result.rowsAffected) rows affected in \(String(format: "%.1f", result.executionTimeMs)) ms"
        }

        return "\(visibleCount) visible rows, \(totalCount) total, \(result.columns.count) columns, \(String(format: "%.1f", result.executionTimeMs)) ms"
    }

    private func color(for value: String) -> Color {
        if value == "NULL" { return .secondary }
        if value == "true" || value == "1" { return .green }
        if value == "false" || value == "0" { return .red }
        if value.hasPrefix("<BLOB") { return .purple }
        if Int(value) != nil || Double(value) != nil { return .orange }
        return .primary
    }

    private var columnWidth: CGFloat { 180 }
}
