import SwiftUI

struct QueryConsole: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            // SQL input area
            HStack(spacing: 0) {
                TextEditor(text: $viewModel.queryText)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(AnvilSpacing.sm)

                // Action buttons
                VStack(spacing: AnvilSpacing.sm) {
                    Button {
                        viewModel.runQuery()
                    } label: {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AnvilColor.accentGreen)
                    }
                    .buttonStyle(.plain)
                    .help("Run Query")
                    .disabled(viewModel.isRunningQuery)

                    Button {
                        viewModel.queryText = ""
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear")

                    Spacer()
                }
                .padding(AnvilSpacing.sm)
            }
            .frame(height: 80)
            .background(AnvilColor.backgroundTertiary)

            Divider().overlay(AnvilColor.borderSubtle)

            // Query history
            if !viewModel.queryHistory.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text("HISTORY")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .tracking(0.3)
                        Spacer()
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AnvilSpacing.xs) {
                            ForEach(viewModel.queryHistory.prefix(5)) { entry in
                                historyChip(entry)
                            }
                        }
                        .padding(.horizontal, AnvilSpacing.md)
                        .padding(.bottom, AnvilSpacing.xs)
                    }
                }
                .background(AnvilColor.backgroundSecondary)
            }
        }
    }

    // MARK: - History Chip

    private func historyChip(_ entry: QueryHistoryEntry) -> some View {
        Text(entry.sql.prefix(40) + (entry.sql.count > 40 ? "..." : ""))
            .font(AnvilFont.code)
            .foregroundStyle(AnvilColor.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xxs)
            .background(AnvilColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.selectHistoryEntry(entry)
            }
    }
}
