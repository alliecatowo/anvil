import Foundation

public protocol RemoteEnvironmentPort: AnvilProviderDefinition {
    func connections() async throws -> [RemoteConnection]
    func connect(connectionId: String) async throws -> RemoteConnection
    func disconnect(connectionId: String) async throws
    func execute(connectionId: String, command: String) async throws -> String
    func openTunnel(connectionId: String, localPort: Int, remotePort: Int) async throws -> Tunnel
    func closeTunnel(tunnelId: String) async throws
    func activeTunnels() async throws -> [Tunnel]
}
