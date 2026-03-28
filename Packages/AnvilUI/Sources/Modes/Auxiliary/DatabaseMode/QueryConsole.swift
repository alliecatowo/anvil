import SwiftUI

struct QueryConsole: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Query Console")
                        .font(.headline)

                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if viewModel.canSortCurrentResults {
                    Menu {
                        Button("Natural Order") {
                            viewModel.sortColumn = nil
                            viewModel.sortAscending = true
                            Task { await viewModel.browseSelectedObject() }
                        }

                        ForEach(viewModel.sortableColumns, id: \.self) { column in
                            Button(column) {
                                viewModel.sortBy(column: column)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }

                Button {
                    viewModel.runQuery()
                } label: {
                    if viewModel.isRunningQuery {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Running...")
                    } else {
                        Label("Run", systemImage: "play.fill")
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.isRunningQuery || viewModel.queryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Execute query")
            }

            TextEditor(text: $viewModel.queryText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary.opacity(0.35))
                }
                .accessibilityLabel("SQL query input")

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusText: String {
        if let selectedObject = viewModel.selectedObject {
            return "Browsing \(selectedObject.kind.rawValue) \(selectedObject.name)"
        }
        return "Run ad hoc SQL against the active connection"
    }
}
