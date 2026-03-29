import Foundation

/// Observable view model that bridges LSP client state to SwiftUI.
///
/// Publishes diagnostics and completions on the main actor for direct use in views.
@MainActor
public final class LSPViewModel: ObservableObject, Sendable {
    @Published public var diagnostics: [LSPDiagnostic] = []
    @Published public var completions: [CompletionItem] = []
    @Published public var isRunning: Bool = false

    private var client: LSPClient?
    private var diagnosticsTask: Task<Void, Never>?
    private var documentVersions: [String: Int] = [:]

    public init() {}

    // MARK: - Lifecycle

    /// Start the LSP server for a given workspace.
    public func start(workspacePath: String) async {
        guard !isRunning else { return }

        let newClient = LSPClient()
        self.client = newClient

        do {
            try await newClient.initialize(workspacePath: workspacePath)
            isRunning = true
            startDiagnosticsListener()
        } catch {
            self.client = nil
            isRunning = false
        }
    }

    /// Stop the LSP server.
    public func stop() async {
        diagnosticsTask?.cancel()
        diagnosticsTask = nil
        await client?.shutdown()
        client = nil
        isRunning = false
        diagnostics = []
        completions = []
        documentVersions = [:]
    }

    // MARK: - Text Synchronization

    /// Called when a file is opened in the editor.
    public func didOpen(uri: String, languageId: String, text: String) async {
        documentVersions[uri] = 1
        await client?.didOpen(uri: uri, languageId: languageId, text: text)
    }

    /// Called when a file's content changes.
    public func didChange(uri: String, text: String) async {
        let version = (documentVersions[uri] ?? 1) + 1
        documentVersions[uri] = version
        await client?.didChange(uri: uri, text: text, version: version)
    }

    /// Called when a file is closed in the editor.
    public func didClose(uri: String) async {
        documentVersions.removeValue(forKey: uri)
        await client?.didClose(uri: uri)
    }

    // MARK: - Completion

    /// Request completions at the given position and update `completions`.
    public func requestCompletion(uri: String, line: Int, character: Int) async {
        guard let client else {
            completions = []
            return
        }
        completions = await client.completion(uri: uri, line: line, character: character)
    }

    /// Clear the current completions list.
    public func clearCompletions() {
        completions = []
    }

    // MARK: - Definition

    /// Request go-to-definition at the given position.
    public func definition(uri: String, line: Int, character: Int) async -> LSPLocation? {
        guard let client else { return nil }
        return await client.definition(uri: uri, line: line, character: character)
    }

    // MARK: - Hover

    /// Request hover documentation at the given position.
    public func hover(uri: String, line: Int, character: Int) async -> LSPHoverResult? {
        guard let client else { return nil }
        return await client.hover(uri: uri, line: line, character: character)
    }

    // MARK: - Diagnostics Listener

    private func startDiagnosticsListener() {
        guard let client else { return }
        diagnosticsTask = Task { [weak self] in
            for await batch in client.diagnosticsStream() {
                guard !Task.isCancelled else { break }
                await self?.handleDiagnosticsBatch(batch)
            }
        }
    }

    private func handleDiagnosticsBatch(_ batch: [LSPDiagnostic]) {
        guard let uri = batch.first?.uri else {
            // Empty batch means diagnostics cleared for some file -- but we
            // cannot determine which file without the uri, so ignore.
            return
        }
        // Replace all diagnostics for this URI with the new batch.
        var current = diagnostics.filter { $0.uri != uri }
        current.append(contentsOf: batch)
        diagnostics = current
    }
}
