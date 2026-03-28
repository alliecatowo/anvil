import Foundation
import Security

/// macOS Keychain wrapper for storing secrets and API tokens.
public struct KeychainStore: Sendable {
    private let service: String

    public init(service: String = "com.anvil.app") {
        self.service = service
    }

    public func get(_ key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status == errSecItemNotFound { return nil }
            throw KeychainError.unhandled(status: status)
        }

        return String(data: data, encoding: .utf8)
    }

    public func set(_ key: String, value: String) throws {
        let data = Data(value.utf8)

        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Add new item
            var addQuery = updateQuery
            addQuery[kSecValueData as String] = data
            // Restrict access: only available after first unlock, never migrated to other devices
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unhandled(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unhandled(status: updateStatus)
        }
    }

    public func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandled(status: status)
        }
    }
}

public enum KeychainError: Error, Sendable {
    case unhandled(status: OSStatus)
}
