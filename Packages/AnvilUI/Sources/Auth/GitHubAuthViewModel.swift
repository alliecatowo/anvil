import SwiftUI
import AnvilGitHub

/// Manages GitHub authentication state and the device flow login process.
@MainActor
final class GitHubAuthViewModel: ObservableObject {
    enum AuthState: Equatable {
        case loggedOut
        case waitingForUserCode(userCode: String, verificationURL: String)
        case polling
        case loggedIn(username: String, avatarURL: String?)
        case error(String)
    }

    @Published var authState: AuthState = .loggedOut
    @Published var isLoggingOut = false

    private let oauthService: GitHubOAuthService
    private var pollTask: Task<Void, Never>?

    var isLoggedIn: Bool {
        if case .loggedIn = authState { return true }
        return false
    }

    var username: String? {
        if case .loggedIn(let name, _) = authState { return name }
        return nil
    }

    var avatarURL: String? {
        if case .loggedIn(_, let url) = authState { return url }
        return nil
    }

    init(clientId: String = "") {
        self.oauthService = GitHubOAuthService(clientId: clientId)
        // Try loading existing token on init
        if let token = oauthService.loadToken() {
            authState = .polling
            Task { await validateExistingToken(token) }
        }
    }

    // MARK: - Login

    func startLogin() {
        guard case .loggedOut = authState else { return }
        if case .error = authState {} else {}

        Task { @MainActor in
            do {
                let response = try await oauthService.requestDeviceCode()
                authState = .waitingForUserCode(
                    userCode: response.userCode,
                    verificationURL: response.verificationURI
                )
                startPolling(deviceCode: response.deviceCode, interval: response.interval, expiresIn: response.expiresIn)
            } catch {
                authState = .error("Failed to start login: \(error.localizedDescription)")
            }
        }
    }

    func cancelLogin() {
        pollTask?.cancel()
        pollTask = nil
        authState = .loggedOut
    }

    func logout(resetAdapter: @escaping () -> Void) {
        isLoggingOut = true
        Task { @MainActor in
            await oauthService.deleteToken()
            resetAdapter()
            authState = .loggedOut
            isLoggingOut = false
        }
    }

    func retryLogin() {
        authState = .loggedOut
        startLogin()
    }

    // MARK: - Private

    private func validateExistingToken(_ token: String) async {
        do {
            let user = try await oauthService.fetchUser(token: token)
            authState = .loggedIn(username: user.login, avatarURL: user.avatarURL)
        } catch {
            // Token is invalid or expired — clear it
            await oauthService.deleteToken()
            authState = .loggedOut
        }
    }

    private func startPolling(deviceCode: String, interval: Int, expiresIn: Int) {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
            let pollInterval = UInt64(max(interval, 5)) * 1_000_000_000

            while !Task.isCancelled && Date() < deadline {
                try? await Task.sleep(nanoseconds: pollInterval)
                guard !Task.isCancelled else { return }

                do {
                    let result = try await oauthService.pollForToken(deviceCode: deviceCode)
                    switch result {
                    case .pending:
                        continue
                    case .success(let token):
                        try? await oauthService.saveToken(token)
                        let user = try await oauthService.fetchUser(token: token)
                        authState = .loggedIn(username: user.login, avatarURL: user.avatarURL)
                        return
                    case .expired:
                        authState = .error("Login expired. Please try again.")
                        return
                    case .denied:
                        authState = .error("Login was denied.")
                        return
                    }
                } catch {
                    authState = .error("Login failed: \(error.localizedDescription)")
                    return
                }
            }

            if !Task.isCancelled {
                authState = .error("Login timed out. Please try again.")
            }
        }
    }
}
