import SwiftUI

struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let tab = viewModel.selectedTab {
                // Terminal output
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(tab.lines) { line in
                                terminalLine(line)
                                    .id(line.id)
                            }
                        }
                        .padding(AnvilSpacing.sm)
                    }
                    .onChange(of: tab.lines.count) { _, _ in
                        if let lastId = tab.lines.last?.id {
                            proxy.scrollTo(lastId, anchor: .bottom)
                        }
                    }
                }

                Divider().overlay(AnvilColor.borderSubtle)

                // Input line
                HStack(spacing: AnvilSpacing.xs) {
                    Text("$")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.accentGreen)

                    TextField("", text: $viewModel.inputText)
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            viewModel.submitInput()
                        }
                }
                .padding(.horizontal, AnvilSpacing.sm)
                .padding(.vertical, AnvilSpacing.xs)
                .background(AnvilColor.backgroundTertiary)
            } else {
                emptyState
            }
        }
        .background(Color(hex: 0x0A0A0A))
    }

    // MARK: - Terminal Line

    private func terminalLine(_ line: TerminalLine) -> some View {
        Text(line.content)
            .font(AnvilFont.code)
            .foregroundStyle(line.style.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 18)
            .textSelection(.enabled)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AnvilSpacing.md) {
            Image(systemName: "terminal")
                .font(.system(size: 32, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary.opacity(0.5))

            Text("No terminal session")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
