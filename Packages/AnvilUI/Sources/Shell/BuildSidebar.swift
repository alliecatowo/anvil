import AppKit
import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers

struct BuildSidebar: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Section", selection: $appState.buildActiveSection) {
                    ForEach(AppState.BuildSection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Build Sidebar Section")

                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.sm)
            .padding(.vertical, AnvilSpacing.xs)

            Divider()

            switch appState.buildActiveSection {
            case .sessions:
                AgentSidebar(viewModel: appState.agentViewModel)
            case .files:
                EditorSidebar(viewModel: appState.editorViewModel)
            case .data:
                DatabaseSidebarView(viewModel: appState.databaseViewModel)
            case .tests:
                TestSuiteList(viewModel: appState.testingViewModel)
            }
        }
    }
}

// MARK: - Database Sidebar

struct DatabaseSidebarView: View {
    @ObservedObject var viewModel: DatabaseViewModel
    @EnvironmentObject private var container: DependencyContainer

    var body: some View {
        Group {
            if viewModel.isConnected {
                SchemaExplorer(viewModel: viewModel) {
                    exportResults()
                }
            } else {
                disconnectedView
            }
        }
        .onAppear {
            viewModel.configure(service: container.databaseService)
        }
    }

    private var disconnectedView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Spacer()

            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 36, weight: .thin))
                .foregroundStyle(AnvilColor.textTertiary)

            Text("No connections")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textSecondary)

            Text("Connect to a database to browse schemas and run queries.")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AnvilSpacing.md)

            if !viewModel.availableProviders.isEmpty {
                VStack(spacing: AnvilSpacing.sm) {
                    Picker("Provider", selection: $viewModel.selectedProviderId) {
                        ForEach(viewModel.availableProviders) { provider in
                            Text(provider.title).tag(Optional(provider.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()

                    if viewModel.selectedProvider?.connectionStyle == .file {
                        HStack(spacing: 8) {
                            TextField("Database file path", text: $viewModel.connectionPath)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(1)

                            Button {
                                openFilePanel()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .buttonStyle(.borderless)
                            .help("Browse for database file")
                        }
                    }

                    Button {
                        Task { await viewModel.connectCurrentProvider() }
                    } label: {
                        Label("Connect", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(
                        viewModel.selectedProvider?.connectionStyle == .file
                        && viewModel.connectionPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding(.horizontal, AnvilSpacing.md)
            } else {
                Text("No database providers available.")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(AnvilFont.label)
                    .foregroundStyle(.red)
                    .padding(.horizontal, AnvilSpacing.md)
            }

            Spacer()
        }
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
        panel.message = "Choose a database file."

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.connectionPath = url.path
        }
    }

    private func exportResults() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = viewModel.connectionTitle
            .replacingOccurrences(of: " ", with: "-")
            .lowercased() + "-results.csv"
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
