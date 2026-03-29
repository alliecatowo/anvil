import SwiftUI

// MARK: - Connection Status

enum IntegrationConnectionStatus: Sendable {
    case disconnected
    case connecting
    case connected(String)
    case failed(String)
}

// MARK: - Integration Settings View

struct IntegrationSettingsView: View {
    // GitHub Issues
    @State private var githubToken: String = ""
    @State private var githubOwner: String = ""
    @State private var githubRepo: String = ""
    @State private var githubStatus: IntegrationConnectionStatus = .disconnected

    // Linear
    @State private var linearApiKey: String = ""
    @State private var linearTeamId: String = ""
    @State private var linearStatus: IntegrationConnectionStatus = .disconnected

    // Slack (external messaging provider)
    @State private var slackBotToken: String = ""
    @State private var slackStatus: IntegrationConnectionStatus = .disconnected

    // Vercel
    @State private var vercelToken: String = ""
    @State private var vercelTeamId: String = ""
    @State private var vercelStatus: IntegrationConnectionStatus = .disconnected

    // Netlify
    @State private var netlifyToken: String = ""
    @State private var netlifySiteId: String = ""
    @State private var netlifyStatus: IntegrationConnectionStatus = .disconnected

    var body: some View {
        Form {
            githubSection
            linearSection
            slackSection
            vercelSection
            netlifySection
        }
        .formStyle(.grouped)
        .onAppear { loadCredentials() }
    }

    // MARK: - GitHub Issues

    private var githubSection: some View {
        Section("GitHub Issues") {
            SecureField("Personal Access Token", text: $githubToken)
            TextField("Repository Owner", text: $githubOwner)
            TextField("Repository Name", text: $githubRepo)
            HStack {
                Button("Connect") {
                    connectGitHub()
                }
                .buttonStyle(.bordered)
                .disabled(githubToken.isEmpty || githubOwner.isEmpty || githubRepo.isEmpty)

                if case .connecting = githubStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                statusLabel(githubStatus)
            }
        }
    }

    // MARK: - Linear

    private var linearSection: some View {
        Section("Linear") {
            SecureField("API Key", text: $linearApiKey)
            TextField("Team ID (optional)", text: $linearTeamId)
            HStack {
                Button("Connect") {
                    connectLinear()
                }
                .buttonStyle(.bordered)
                .disabled(linearApiKey.isEmpty)

                if case .connecting = linearStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                statusLabel(linearStatus)
            }
        }
    }

    // MARK: - Slack

    private var slackSection: some View {
        Section("Chat — Slack") {
            SecureField("Bot Token", text: $slackBotToken)
            Text("Anvil supports multiple messaging providers. Slack is one external provider option; local in-memory messaging remains available as a fallback.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Connect") {
                    connectSlack()
                }
                .buttonStyle(.bordered)
                .disabled(slackBotToken.isEmpty)

                if case .connecting = slackStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                statusLabel(slackStatus)
            }
        }
    }

    // MARK: - Vercel

    private var vercelSection: some View {
        Section("Vercel") {
            SecureField("API Token", text: $vercelToken)
            TextField("Team ID (optional)", text: $vercelTeamId)
            HStack {
                Button("Connect") {
                    connectVercel()
                }
                .buttonStyle(.bordered)
                .disabled(vercelToken.isEmpty)

                if case .connecting = vercelStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                statusLabel(vercelStatus)
            }
        }
    }

    // MARK: - Netlify

    private var netlifySection: some View {
        Section("Netlify") {
            SecureField("Personal Access Token", text: $netlifyToken)
            TextField("Site ID (optional)", text: $netlifySiteId)
            HStack {
                Button("Connect") {
                    connectNetlify()
                }
                .buttonStyle(.bordered)
                .disabled(netlifyToken.isEmpty)

                if case .connecting = netlifyStatus {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
                statusLabel(netlifyStatus)
            }
        }
    }

    // MARK: - Status Label

    @ViewBuilder
    private func statusLabel(_ status: IntegrationConnectionStatus) -> some View {
        switch status {
        case .disconnected:
            EmptyView()
        case .connecting:
            EmptyView()
        case .connected(let detail):
            Label(detail, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        case .failed(let reason):
            Label(reason, systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }

    // MARK: - Load Credentials

    private func loadCredentials() {
        githubToken = ProviderKeychain.githubToken ?? ""
        githubOwner = ProviderKeychain.githubOwner ?? ""
        githubRepo = ProviderKeychain.githubRepo ?? ""
        if !githubToken.isEmpty {
            githubStatus = .connected("Connected")
        }

        linearApiKey = ProviderKeychain.linearApiKey ?? ""
        linearTeamId = ProviderKeychain.linearTeamId ?? ""
        if !linearApiKey.isEmpty {
            linearStatus = .connected("Connected")
        }

        slackBotToken = ProviderKeychain.slackToken ?? ""
        if !slackBotToken.isEmpty {
            slackStatus = .connected("Connected")
        }

        vercelToken = ProviderKeychain.vercelToken ?? ""
        vercelTeamId = ProviderKeychain.vercelTeamId ?? ""
        if !vercelToken.isEmpty {
            vercelStatus = .connected("Connected")
        }

        netlifyToken = ProviderKeychain.netlifyToken ?? ""
        netlifySiteId = ProviderKeychain.netlifySiteId ?? ""
        if !netlifyToken.isEmpty {
            netlifyStatus = .connected("Connected")
        }
    }

    // MARK: - Connect GitHub

    private func connectGitHub() {
        githubStatus = .connecting

        ProviderKeychain.githubToken = githubToken
        ProviderKeychain.githubOwner = githubOwner
        ProviderKeychain.githubRepo = githubRepo

        // Validate by making a test request to the GitHub API
        let urlString = "https://api.github.com/repos/\(githubOwner)/\(githubRepo)"
        guard let url = URL(string: urlString) else {
            githubStatus = .failed("Invalid repository URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(githubToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        githubStatus = .connected("Connected to \(githubOwner)/\(githubRepo)")
                        NotificationCenter.default.post(
                            name: .anvilIntegrationCredentialsChanged,
                            object: nil,
                            userInfo: ["provider": "github-issues"]
                        )
                    } else if httpResponse.statusCode == 401 {
                        githubStatus = .failed("Invalid token")
                    } else if httpResponse.statusCode == 404 {
                        githubStatus = .failed("Repository not found")
                    } else {
                        githubStatus = .failed("HTTP \(httpResponse.statusCode)")
                    }
                }
            } catch {
                githubStatus = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Connect Linear

    private func connectLinear() {
        linearStatus = .connecting

        ProviderKeychain.linearApiKey = linearApiKey
        ProviderKeychain.linearTeamId = linearTeamId.isEmpty ? nil : linearTeamId

        // Validate by making a test request to the Linear API
        guard let url = URL(string: "https://api.linear.app/graphql") else {
            linearStatus = .failed("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(linearApiKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(#"{"query":"{ viewer { id name } }"}"#.utf8)

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        // Try to extract the user name from the response
                        var detail = "Connected"
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let dataObj = json["data"] as? [String: Any],
                           let viewer = dataObj["viewer"] as? [String: Any],
                           let name = viewer["name"] as? String {
                            detail = "Connected as \(name)"
                        }
                        linearStatus = .connected(detail)
                        NotificationCenter.default.post(
                            name: .anvilIntegrationCredentialsChanged,
                            object: nil,
                            userInfo: ["provider": "linear"]
                        )
                    } else if httpResponse.statusCode == 401 {
                        linearStatus = .failed("Invalid API key")
                    } else {
                        linearStatus = .failed("HTTP \(httpResponse.statusCode)")
                    }
                }
            } catch {
                linearStatus = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Connect Slack

    private func connectSlack() {
        slackStatus = .connecting

        ProviderKeychain.slackToken = slackBotToken

        // Validate by making a test request to the Slack API
        guard let url = URL(string: "https://slack.com/api/auth.test") else {
            slackStatus = .failed("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(slackBotToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let ok = json["ok"] as? Bool {
                        if ok {
                            let team = json["team"] as? String ?? ""
                            slackStatus = .connected(team.isEmpty ? "Connected" : "Connected to \(team)")
                            NotificationCenter.default.post(
                                name: .anvilIntegrationCredentialsChanged,
                                object: nil,
                                userInfo: ["provider": "slack"]
                            )
                        } else {
                            let errorMsg = json["error"] as? String ?? "Unknown error"
                            slackStatus = .failed(errorMsg)
                        }
                    }
                } else {
                    slackStatus = .failed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
                }
            } catch {
                slackStatus = .failed(error.localizedDescription)
            }
        }
    }
    // MARK: - Connect Vercel

    private func connectVercel() {
        vercelStatus = .connecting

        ProviderKeychain.vercelToken = vercelToken
        ProviderKeychain.vercelTeamId = vercelTeamId.isEmpty ? nil : vercelTeamId

        guard let url = URL(string: "https://api.vercel.com/v2/user") else {
            vercelStatus = .failed("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(vercelToken)", forHTTPHeaderField: "Authorization")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        var detail = "Connected"
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let user = json["user"] as? [String: Any],
                           let username = user["username"] as? String {
                            detail = "Connected as \(username)"
                        }
                        vercelStatus = .connected(detail)
                        NotificationCenter.default.post(
                            name: .anvilIntegrationCredentialsChanged,
                            object: nil,
                            userInfo: ["provider": "vercel"]
                        )
                    } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                        vercelStatus = .failed("Invalid token")
                    } else {
                        vercelStatus = .failed("HTTP \(httpResponse.statusCode)")
                    }
                }
            } catch {
                vercelStatus = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Connect Netlify

    private func connectNetlify() {
        netlifyStatus = .connecting

        ProviderKeychain.netlifyToken = netlifyToken
        ProviderKeychain.netlifySiteId = netlifySiteId.isEmpty ? nil : netlifySiteId

        guard let url = URL(string: "https://api.netlify.com/api/v1/user") else {
            netlifyStatus = .failed("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(netlifyToken)", forHTTPHeaderField: "Authorization")

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        var detail = "Connected"
                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let fullName = json["full_name"] as? String, !fullName.isEmpty {
                            detail = "Connected as \(fullName)"
                        }
                        netlifyStatus = .connected(detail)
                        NotificationCenter.default.post(
                            name: .anvilIntegrationCredentialsChanged,
                            object: nil,
                            userInfo: ["provider": "netlify"]
                        )
                    } else if httpResponse.statusCode == 401 {
                        netlifyStatus = .failed("Invalid token")
                    } else {
                        netlifyStatus = .failed("HTTP \(httpResponse.statusCode)")
                    }
                }
            } catch {
                netlifyStatus = .failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let anvilIntegrationCredentialsChanged = Notification.Name("anvilIntegrationCredentialsChanged")
}
