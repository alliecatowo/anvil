import Foundation

/// Manages GitHub OAuth using the Device Flow.
///
/// Device Flow is ideal for native macOS apps — shows a user code,
/// user visits github.com/login/device, enters the code, and we poll for the token.
public actor GitHubOAuthService {
    private let clientId: String
    private let scopes: String
    private let session: URLSession

    /// The Keychain account key for storing the GitHub token.
    public static let keychainAccount = "github-oauth-token"

    public init(clientId: String, scopes: String = "repo read:user") {
        self.clientId = clientId
        self.scopes = scopes
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Device Flow Step 1: Request device code

    public struct DeviceCodeResponse: Sendable {
        public let deviceCode: String
        public let userCode: String
        public let verificationURI: String
        public let expiresIn: Int
        public let interval: Int
    }

    public func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=\(scopes.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopes)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.deviceCodeRequestFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        guard let deviceCode = json["device_code"] as? String,
              let userCode = json["user_code"] as? String,
              let verificationURI = json["verification_uri"] as? String else {
            throw OAuthError.invalidDeviceCodeResponse
        }

        return DeviceCodeResponse(
            deviceCode: deviceCode,
            userCode: userCode,
            verificationURI: verificationURI,
            expiresIn: json["expires_in"] as? Int ?? 900,
            interval: json["interval"] as? Int ?? 5
        )
    }

    // MARK: - Device Flow Step 2: Poll for access token

    public enum PollResult: Sendable {
        case pending
        case success(token: String)
        case expired
        case denied
    }

    public func pollForToken(deviceCode: String) async throws -> PollResult {
        var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.tokenPollFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]

        if let token = json["access_token"] as? String {
            return .success(token: token)
        }

        switch json["error"] as? String {
        case "authorization_pending", "slow_down":
            return .pending
        case "expired_token":
            return .expired
        case "access_denied":
            return .denied
        default:
            return .pending
        }
    }

    // MARK: - Fetch authenticated user

    public struct GitHubUser: Sendable {
        public let login: String
        public let name: String?
        public let avatarURL: String?
        public let id: Int
    }

    public func fetchUser(token: String) async throws -> GitHubUser {
        var request = URLRequest(url: URL(string: "https://api.github.com/user")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw OAuthError.userFetchFailed
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let login = json["login"] as? String, let id = json["id"] as? Int else {
            throw OAuthError.invalidUserResponse
        }

        return GitHubUser(
            login: login,
            name: json["name"] as? String,
            avatarURL: json["avatar_url"] as? String,
            id: id
        )
    }

    // MARK: - Token management

    public func saveToken(_ token: String) throws {
        try KeychainHelper.save(account: Self.keychainAccount, token: token)
    }

    public nonisolated func loadToken() -> String? {
        KeychainHelper.load(account: Self.keychainAccount)
    }

    public func deleteToken() {
        KeychainHelper.delete(account: Self.keychainAccount)
    }
}

public enum OAuthError: Error, Sendable {
    case deviceCodeRequestFailed
    case invalidDeviceCodeResponse
    case tokenPollFailed
    case tokenExpired
    case accessDenied
    case userFetchFailed
    case invalidUserResponse
}
