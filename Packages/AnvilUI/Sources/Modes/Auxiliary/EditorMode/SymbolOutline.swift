import SwiftUI

struct SymbolOutline: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Outline")
                    .font(.headline)

                Spacer()

                Text("\(viewModel.symbols.count)")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            if viewModel.symbols.isEmpty {
                emptyState
            } else {
                symbolList
            }
        }
    }

    // MARK: - Symbol List

    private var symbolList: some View {
        List {
            ForEach(viewModel.symbols) { symbol in
                symbolRow(symbol)
            }
        }
        .listStyle(.sidebar)
    }

    private func symbolRow(_ symbol: EditorSymbol) -> some View {
        let isAtCursor = viewModel.symbolAtCursor?.id == symbol.id

        return HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: symbol.kind.icon)
                .font(.system(size: 11))
                .foregroundStyle(symbol.kind.color)
                .frame(width: 16)
                .accessibilityHidden(true)

            Text(symbol.name)
                .font(AnvilFont.code)
                .foregroundStyle(isAtCursor ? .primary : .secondary)
                .lineLimit(1)

            Spacer()

            Text("L\(symbol.line)")
                .font(AnvilFont.label)
                .foregroundStyle(.tertiary)
        }
        .listRowBackground(isAtCursor ? Color.accentColor.opacity(0.14) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.navigateToSymbol(symbol)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(symbol.name), line \(symbol.line)")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Symbols", systemImage: "list.bullet.indent")
        } description: {
            Text("Open a file to see its symbol outline.")
        }
    }
}
