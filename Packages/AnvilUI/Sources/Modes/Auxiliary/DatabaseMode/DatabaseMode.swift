import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DatabaseMode: View {
    @EnvironmentObject private var container: DependencyContainer
    @StateObject private var viewModel = DatabaseViewModel()

    var body: some View {
        Group {
            if viewModel.isConnected {
                connectedWorkspace
            } else {
                connectionWorkspace
            }
        }
        .background(.background)
        .onAppear {
            viewModel.configure(service: container.databaseService)
        }
    }

    private var connectedWorkspace: some View {
        NavigationSplitView {
            SchemaExplorer(viewModel: viewModel) {
                exportResults()
            }
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 360)
        } detail: {
            VSplitView {
                QueryConsole(viewModel: viewModel)
                    .frame(minHeight: 180, idealHeight: 230)

                ResultsTable(viewModel: viewModel)
                    .frame(minHeight: 280)
            }
            .padding(20)
            .background(.background)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var connectionWorkspace: some View {
        VStack {
            Spacer()

            Form {
                Section {
                    Picker("Provider", selection: $viewModel.selectedProviderId) {
                        ForEach(viewModel.availableProviders) { provider in
                            Text(provider.title).tag(Optional(provider.id))
                        }
                    }
                    .pickerStyle(.menu)

                    if let provider = viewModel.selectedProvider {
                        LabeledContent("Capabilities") {
                            Text(provider.summary)
                                .foregroundStyle(.secondary)
                        }

                        if provider.connectionStyle == .file {
                            LabeledContent("Database File") {
                                HStack(spacing: 12) {
                                    TextField("Choose a database file", text: $viewModel.connectionPath)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))

                                    Button("Browse…") {
                                        openFilePanel()
                                    }
                                }
                            }

                            if !provider.supportedFileExtensions.isEmpty {
                                LabeledContent("Supported") {
                                    Text(provider.supportedFileExtensions.joined(separator: ", "))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if let notes = provider.notes {
                            Text(notes)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Connection")
                } footer: {
                    Text("Anvil only shows providers that are actually registered in the app. SQLite ships today. Other providers can be added without changing this UI model.")
                }
            }
            .formStyle(.grouped)
            .frame(maxWidth: 720)

            HStack(spacing: 12) {
                Button("Connect") {
                    Task { await viewModel.connectCurrentProvider() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.selectedProvider?.connectionStyle == .file && viewModel.connectionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, 12)

            Spacer()
        }
        .padding(32)
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .data,
            UTType(filenameExtension: "sqlite"),
            UTType(filenameExtension: "sqlite3"),
            UTType(filenameExtension: "db"),
        ].compactMap { $0 }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Open Database"
        panel.message = "Choose a database file for the selected provider."

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.connectionPath = url.path
        }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = viewModel.connectionTitle.replacingOccurrences(of: " ", with: "-").lowercased() + "-results.csv"
        panel.title = "Export Query Results"
        panel.message = "Save the current result set as CSV."

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try viewModel.exportResults(to: url)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }
}
