import Foundation

public protocol SecretsPort: AnvilProviderDefinition {
    func vaults() async throws -> [Vault]
    func secrets(vaultId: String) async throws -> [Secret]
    func secret(vaultId: String, key: String) async throws -> Secret
    func setSecret(vaultId: String, key: String, value: String) async throws
    func deleteSecret(vaultId: String, key: String) async throws
    func rotateSecret(vaultId: String, key: String) async throws -> Secret
}
