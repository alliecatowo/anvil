import Foundation
import AnvilDomain

/// Application-layer service for database operations.
/// Mediates between the UI and the DatabasePort adapter.
@MainActor
public final class DatabaseService: ObservableObject {
    private var providers: [String: any DatabasePort] = [:]

    @Published public var isConnected: Bool = false
    @Published public var currentSchema: Schema?
    @Published public var lastError: String?
    @Published public private(set) var activeConnection: DatabaseConnection?
    @Published public private(set) var availableProviders: [DatabaseProviderDescriptor] = []

    public init() {}

    public func registerProvider(_ provider: any DatabasePort) {
        providers[provider.providerId] = provider
        availableProviders = providers.values
            .map(\.descriptor)
            .sorted {
                if $0.kind == $1.kind {
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                return $0.kind.rawValue < $1.kind.rawValue
            }
    }

    public func setAdapter(_ adapter: any DatabasePort) {
        registerProvider(adapter)
    }

    // MARK: - Connection

    public func connect(_ connection: DatabaseConnection) async {
        guard let provider = providers[connection.providerId] else {
            lastError = "No database provider registered for \(connection.providerId)"
            isConnected = false
            return
        }

        do {
            let resolvedConnection = try await provider.connect(connection: connection)
            activeConnection = resolvedConnection
            isConnected = true
            lastError = nil
            await refreshSchema()
        } catch {
            activeConnection = nil
            currentSchema = nil
            lastError = error.localizedDescription
            isConnected = false
        }
    }

    public func connect(path: String) async {
        guard let provider = availableProviders.first(where: { $0.kind == .sqlite }) else {
            lastError = "No SQLite database provider configured"
            return
        }

        let connection = DatabaseConnection(
            name: URL(fileURLWithPath: path).lastPathComponent,
            providerId: provider.id,
            providerKind: provider.kind,
            configuration: .sqlite(filePath: path)
        )
        await connect(connection)
    }

    public func disconnect() async {
        guard let connection = activeConnection,
              let provider = providers[connection.providerId] else { return }
        try? await provider.disconnect(connectionId: connection.id)
        activeConnection = nil
        isConnected = false
        currentSchema = nil
        lastError = nil
    }

    // MARK: - Schema

    public func refreshSchema() async {
        guard let connection = activeConnection,
              let provider = providers[connection.providerId] else { return }
        do {
            currentSchema = try await provider.schema(connectionId: connection.id)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Query

    public func executeQuery(_ sql: String) async -> QueryResult? {
        guard let connection = activeConnection,
              let provider = providers[connection.providerId] else {
            lastError = "Not connected"
            return nil
        }
        do {
            let result = try await provider.execute(connectionId: connection.id, query: sql)
            lastError = nil
            return result
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    public func browse(_ request: DatabaseBrowseRequest) async -> QueryResult? {
        guard let connection = activeConnection,
              let provider = providers[connection.providerId] else {
            lastError = "Not connected"
            return nil
        }

        do {
            let result = try await provider.browse(connectionId: connection.id, request: request)
            lastError = nil
            return result
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    // MARK: - Table Browse

    public func tableNames() async -> [String] {
        guard let connection = activeConnection,
              let provider = providers[connection.providerId] else { return [] }
        return (try? await provider.tables(connectionId: connection.id)) ?? []
    }

    public var connectionId: String? { activeConnection?.id }
}
