import Foundation
import Security

/// Keychain wrapper for storing integration provider tokens.
/// Uses the macOS Keychain Services API directly (no Infrastructure dependency).
enum ProviderKeychain {
    private static let service = "com.anvil.providers"

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        // Delete existing
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Provider-specific keys

    static var vercelToken: String? {
        get { get("vercel.apiToken") }
        set {
            if let newValue { set("vercel.apiToken", value: newValue) }
            else { delete("vercel.apiToken") }
        }
    }

    static var vercelTeamId: String? {
        get { get("vercel.teamId") }
        set {
            if let newValue, !newValue.isEmpty { set("vercel.teamId", value: newValue) }
            else { delete("vercel.teamId") }
        }
    }

    static var sentryToken: String? {
        get { get("sentry.authToken") }
        set {
            if let newValue { set("sentry.authToken", value: newValue) }
            else { delete("sentry.authToken") }
        }
    }

    static var sentryOrganization: String? {
        get { get("sentry.organization") }
        set {
            if let newValue, !newValue.isEmpty { set("sentry.organization", value: newValue) }
            else { delete("sentry.organization") }
        }
    }

    static var slackToken: String? {
        get { get("slack.botToken") }
        set {
            if let newValue { set("slack.botToken", value: newValue) }
            else { delete("slack.botToken") }
        }
    }

    static var dockerSocketPath: String? {
        get { get("docker.socketPath") }
        set {
            if let newValue, !newValue.isEmpty { set("docker.socketPath", value: newValue) }
            else { delete("docker.socketPath") }
        }
    }
}
