import SwiftUI

struct ResultsTable: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let result = viewModel.queryResult {
                // Column headers
                headerRow(result.columns)

                Divider().overlay(AnvilColor.borderMedium)

                // Data rows
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(result.rows.enumerated()), id: \.offset) { index, row in
                            dataRow(row, columns: result.columns, index: index)

                            if index < result.rows.count - 1 {
                                Divider().overlay(AnvilColor.borderSubtle)
                            }
                        }
                    }
                }

                Divider().overlay(AnvilColor.borderSubtle)

                // Footer with row count and pagination
                footer(rowCount: result.rows.count)
            } else {
                emptyState
            }
        }
    }

    // MARK: - Header Row

    private func headerRow(_ columns: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                HStack(spacing: AnvilSpacing.xxs) {
                    Text(column)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .lineLimit(1)

                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 8))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xs)

                if index < columns.count - 1 {
                    Rectangle()
                        .fill(AnvilColor.borderSubtle)
                        .frame(width: 1)
                }
            }
        }
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Data Row

    private func dataRow(_ row: [String], columns: [String], index: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.enumerated()), id: \.offset) { colIndex, value in
                Text(value)
                    .font(AnvilFont.code)
                    .foregroundStyle(cellColor(value))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xs)

                if colIndex < row.count - 1 {
                    Rectangle()
                        .fill(AnvilColor.borderSubtle)
                        .frame(width: 1)
                }
            }
        }
        .background(index % 2 == 0 ? Color.clear : AnvilColor.backgroundSecondary.opacity(0.3))
    }

    // MARK: - Footer

    private func footer(rowCount: Int) -> some View {
        HStack {
            Text("\(rowCount) row\(rowCount == 1 ? "" : "s")")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)

            Spacer()

            Text("Page \(viewModel.currentPage + 1)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "tablecells")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("Run a query to see results")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func cellColor(_ value: String) -> Color {
        if value == "true" { return AnvilColor.accentGreen }
        if value == "false" { return AnvilColor.accentRed }
        if value == "NULL" { return AnvilColor.textTertiary }
        if Int(value) != nil || Double(value) != nil { return AnvilColor.accentAmber }
        return AnvilColor.textPrimary
    }
}
