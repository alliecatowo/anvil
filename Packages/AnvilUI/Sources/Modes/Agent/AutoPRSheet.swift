import SwiftUI
import AnvilDomain

// MARK: - AutoPRState

enum AutoPRState {
    case generating        // AI is writing title + body
    case ready             // editable, ready to submit
    case submitting        // API call in flight
    case submitted(url: String) // PR created
    case failed(String)
}

// MARK: - AutoPRSheet

/// Sheet that auto-generates a PR title and description from the agent session
/// conversation, lets the user edit them, and creates the PR via GitHub.
struct AutoPRSheet: View {
    let session: AgentSession
    let onDismiss: () -> Void

    @EnvironmentObject var container: DependencyContainer
    @EnvironmentObject var appState: AppState

    @State private var state: AutoPRState = .generating
    @State private var title: String = ""
    @State private var body: String = ""
    @State private var sourceBranch: String = ""
    @State private var targetBranch: String = "main"
    @State private var isDraft: Bool = false
    @State private var repoName: String = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.triangle.pull")
                    .font(.system(size: 15))
                    .foregroundStyle(AnvilColor.accentPurple)
                Text("Create Pull Request")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.lg)
            .padding(.top, AnvilSpacing.lg)
            .padding(.bottom, AnvilSpacing.md)

            Divider().overlay(AnvilColor.borderSubtle)

            switch state {
            case .generating:
                generatingView

            case .ready, .failed:
                formView

            case .submitting:
                submittingView

            case .submitted(let url):
                submittedView(url: url)
            }
        }
        .frame(width: 620)
        .background(AnvilColor.backgroundPrimary)
        .task { await setup() }
    }

    // MARK: - Sub-views

    private var generatingView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            AnvilLoadingIndicator(size: 32)
            VStack(spacing: AnvilSpacing.xs) {
                Text("Generating PR description...")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text("Reading session conversation to write a useful PR body")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnvilSpacing.xl * 2)
    }

    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnvilSpacing.lg) {

                // AI generation notice
                if case .ready = state {
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.accentPurple)
                        Text("AI-generated from your session — edit before submitting")
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.accentPurple.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                if case .failed(let msg) = state {
                    HStack(spacing: AnvilSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(AnvilColor.accentAmber)
                        Text(msg)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textSecondary)
                    }
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.accentAmber.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Title
                fieldLabel("Title")
                TextField("PR title", text: $title)
                    .textFieldStyle(.plain)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(AnvilColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )
                    .focused($titleFocused)

                // Body
                fieldLabel("Description")
                TextEditor(text: $body)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, AnvilSpacing.sm)
                    .padding(.vertical, AnvilSpacing.xs)
                    .frame(minHeight: 200)
                    .background(AnvilColor.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )

                // Branch config
                HStack(spacing: AnvilSpacing.lg) {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                        fieldLabel("From branch")
                        TextField("source", text: $sourceBranch)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.md)
                            .padding(.vertical, AnvilSpacing.sm)
                            .background(AnvilColor.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AnvilColor.borderMedium, lineWidth: 1)
                            )
                    }
                    VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                        fieldLabel("Into branch")
                        TextField("main", text: $targetBranch)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.md)
                            .padding(.vertical, AnvilSpacing.sm)
                            .background(AnvilColor.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AnvilColor.borderMedium, lineWidth: 1)
                            )
                    }
                }

                // Repo + Draft toggle
                HStack {
                    VStack(alignment: .leading, spacing: AnvilSpacing.xs) {
                        fieldLabel("Repository")
                        TextField("owner/repo", text: $repoName)
                            .textFieldStyle(.plain)
                            .font(AnvilFont.code)
                            .foregroundStyle(AnvilColor.textPrimary)
                            .padding(.horizontal, AnvilSpacing.md)
                            .padding(.vertical, AnvilSpacing.sm)
                            .background(AnvilColor.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AnvilColor.borderMedium, lineWidth: 1)
                            )
                    }
                    .frame(maxWidth: .infinity)

                    Toggle("Draft PR", isOn: $isDraft)
                        .toggleStyle(.switch)
                        .tint(AnvilColor.accentPurple)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textSecondary)
                        .padding(.top, AnvilSpacing.lg)
                }

                // Actions
                HStack {
                    Spacer()
                    AnvilButton("Cancel", style: .ghost) { onDismiss() }
                    AnvilButton(
                        "Create Pull Request",
                        icon: "arrow.triangle.pull",
                        style: .primary
                    ) {
                        Task { await submitPR() }
                    }
                    .disabled(title.isEmpty || sourceBranch.isEmpty || repoName.isEmpty)
                }
                .padding(.top, AnvilSpacing.sm)
            }
            .padding(AnvilSpacing.lg)
        }
    }

    private var submittingView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            AnvilLoadingIndicator(size: 32)
            Text("Creating pull request...")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnvilSpacing.xl * 2)
    }

    private func submittedView(url: String) -> some View {
        VStack(spacing: AnvilSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(AnvilColor.accentGreen)

            VStack(spacing: AnvilSpacing.xs) {
                Text("Pull request created!")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text(url)
                    .font(AnvilFont.code)
                    .foregroundStyle(AnvilColor.accentBlue)
                    .textSelection(.enabled)
            }

            HStack(spacing: AnvilSpacing.md) {
                AnvilButton("Open in Browser", icon: "safari", style: .secondary) {
                    if let nsUrl = URL(string: url) {
                        NSWorkspace.shared.open(nsUrl)
                    }
                }
                AnvilButton("Done", style: .primary) { onDismiss() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AnvilSpacing.xl * 2)
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(AnvilFont.label)
            .foregroundStyle(AnvilColor.textSecondary)
    }

    // MARK: - Logic

    private func setup() async {
        // Load current branch as source
        if let adapter = container.getOrCreateGitAdapter() {
            if let branch = try? await adapter.currentBranch() {
                sourceBranch = branch.name
            }
            // Try to derive repo name from git remote
            if let remoteURL = try? await adapter.remoteURL(),
               let derived = extractRepoFullName(from: remoteURL) {
                repoName = derived
            }
        }

        // Generate title + body from session conversation via ACP
        await generatePRDescription()
    }

    private func generatePRDescription() async {
        let conversationSummary = buildConversationSummary(session)
        guard !conversationSummary.isEmpty else {
            title = session.displayName
            body = "*No conversation content to summarize.*"
            state = .ready
            return
        }

        let prompt = """
        You are writing a pull request description for code changes made by an AI agent.

        Here is the agent session that produced this work:

        ---
        \(conversationSummary)
        ---

        Write a concise, professional PR **title** and **description** in the following format:

        TITLE: <one line title, imperative mood, max 72 chars>

        BODY:
        ## Summary
        <2-4 bullet points of what changed>

        ## Changes
        <list key files or components modified>

        ## Testing
        <brief note on how to verify>

        Output ONLY the TITLE: line and BODY: section. No other text.
        """

        let client = await container.getOrCreateACPClient()
        do {
            let response = try await client.complete(prompt: prompt)
            let parsed = parsePRDescription(response)
            title = parsed.title
            body = parsed.body
            state = .ready
            titleFocused = true
        } catch {
            // Fall back to session name as title
            title = session.displayName
            body = "Generated from agent session `\(session.id)`.\n\n\(conversationSummary.prefix(500))"
            state = .ready
        }
    }

    private func submitPR() async {
        guard let adapter = container.getOrCreateGitHubAdapter() else {
            state = .failed("No GitHub provider configured. Add a GitHub token in Settings → Providers.")
            return
        }

        state = .submitting

        do {
            let pr = try await adapter.createPullRequest(
                repo: repoName,
                title: title,
                body: body,
                source: sourceBranch,
                target: targetBranch,
                isDraft: isDraft
            )
            state = .submitted(url: pr.url ?? "https://github.com/\(repoName)/pulls")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func buildConversationSummary(_ session: AgentSession) -> String {
        let messages = session.messages.prefix(30)
        guard !messages.isEmpty else { return "" }

        var parts: [String] = []
        for message in messages {
            let role = message.role == .user ? "User" : "Agent"
            let content = message.content.prefix(400)
            if !content.isEmpty {
                parts.append("[\(role)]: \(content)")
            }
            // Include tool call names for context
            for toolCall in message.toolCalls.prefix(5) {
                parts.append("  [Tool: \(toolCall.name)]")
            }
        }
        return parts.joined(separator: "\n")
    }

    private func parsePRDescription(_ text: String) -> (title: String, body: String) {
        var extractedTitle = ""
        var extractedBody = ""
        var inBody = false

        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("TITLE:") {
                extractedTitle = String(line.dropFirst("TITLE:".count)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("BODY:") {
                inBody = true
                let rest = String(line.dropFirst("BODY:".count)).trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { extractedBody = rest }
            } else if inBody {
                extractedBody += (extractedBody.isEmpty ? "" : "\n") + line
            }
        }

        // Fallback: if parsing fails, use first line as title
        if extractedTitle.isEmpty {
            let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            extractedTitle = String(lines.first ?? "Changes from agent session").prefix(72)
            extractedBody = lines.dropFirst().joined(separator: "\n")
        }

        return (extractedTitle, extractedBody.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func extractRepoFullName(from url: String) -> String? {
        // SSH: git@github.com:owner/repo.git
        if url.contains("github.com:") {
            let parts = url.components(separatedBy: "github.com:")
            return parts.last?.replacingOccurrences(of: ".git", with: "")
        }
        // HTTPS: https://github.com/owner/repo.git
        if url.contains("github.com/") {
            let parts = url.components(separatedBy: "github.com/")
            return parts.last?.replacingOccurrences(of: ".git", with: "")
        }
        return nil
    }
}
