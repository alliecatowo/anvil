import SwiftUI

struct SymbolOutline: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("OUTLINE")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

                Spacer()

                Text("\(viewModel.symbols.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            if viewModel.symbols.isEmpty {
                emptyState
            } else {
                symbolList
            }
        }
    }

    // MARK: - Symbol List

    private var symbolList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.symbols) { symbol in
                    symbolRow(symbol)
                }
            }
            .padding(.vertical, AnvilSpacing.xxs)
        }
    }

    private func symbolRow(_ symbol: EditorSymbol) -> some View {
        let isAtCursor = symbol.line == viewModel.cursorLine

        return HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: symbol.kind.icon)
                .font(.system(size: 11))
                .foregroundStyle(symbol.kind.color)
                .frame(width: 16)

            Text(symbol.name)
                .font(AnvilFont.code)
                .foregroundStyle(isAtCursor ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            Spacer()

            Text("L\(symbol.line)")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xxs)
        .frame(height: 28)
        .background(isAtCursor ? AnvilColor.selectionBackground.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.navigateToSymbol(symbol)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.sm) {
            Spacer()
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 24, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))
            Text("No symbols")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
