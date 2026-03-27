import SwiftUI

struct SchemaExplorer: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SCHEMA")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

                Spacer()

                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            // Table list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.tables) { table in
                        tableRow(table)

                        if viewModel.expandedTableIds.contains(table.id) {
                            ForEach(table.columns) { column in
                                columnRow(column, tableId: table.id)
                            }
                        }
                    }
                }
                .padding(.vertical, AnvilSpacing.xxs)
            }
        }
    }

    // MARK: - Table Row

    private func tableRow(_ table: DatabaseTable) -> some View {
        let isExpanded = viewModel.expandedTableIds.contains(table.id)
        let isSelected = viewModel.selectedTableId == table.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(AnvilColor.textTertiary)
                .frame(width: 12)

            Image(systemName: "tablecells")
                .font(.system(size: 11))
                .foregroundStyle(AnvilColor.accentBlue)
                .frame(width: 16)

            Text(table.name)
                .font(AnvilFont.code)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            Spacer()

            Text("\(table.columns.count)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .frame(height: 24)
        .background(isSelected ? AnvilColor.selectionBackground : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectTable(table.id)
            viewModel.toggleTable(table.id)
        }
    }

    // MARK: - Column Row

    private func columnRow(_ column: DatabaseColumn, tableId: UUID) -> some View {
        HStack(spacing: AnvilSpacing.xxs) {
            Spacer().frame(width: 28)

            Image(systemName: constraintIcon(column.constraint))
                .font(.system(size: 9))
                .foregroundStyle(constraintColor(column.constraint))
                .frame(width: 14)

            Text(column.name)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.textSecondary)
                .lineLimit(1)

            Spacer()

            Text(column.type)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .frame(height: 22)
    }

    // MARK: - Helpers

    private func constraintIcon(_ constraint: String?) -> String {
        guard let c = constraint else { return "circle" }
        if c.contains("PRIMARY KEY") { return "key.fill" }
        if c.contains("REFERENCES") { return "link" }
        if c.contains("UNIQUE") { return "star" }
        return "circle"
    }

    private func constraintColor(_ constraint: String?) -> Color {
        guard let c = constraint else { return AnvilColor.textTertiary }
        if c.contains("PRIMARY KEY") { return AnvilColor.accentAmber }
        if c.contains("REFERENCES") { return AnvilColor.accentPurple }
        if c.contains("UNIQUE") { return AnvilColor.accentTeal }
        return AnvilColor.textTertiary
    }
}
