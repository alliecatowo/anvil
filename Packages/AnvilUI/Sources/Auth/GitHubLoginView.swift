import SwiftUI
import AnvilDomain

/// GitHub login sheet — shows device flow UI or logged-in state.
struct GitHubLoginView: View {
    @ObservedObject var viewModel: GitHubAuthViewModel
    @EnvironmentObject var container: DependencyContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: AnvilSpacing.xl) {
            // Header
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 40))
                .foregroundStyle(AnvilColor.textSecondary)
                .padding(.top, AnvilSpacing.xl)

            Text("GitHub Authentication")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            switch viewModel.authState {
            case .loggedOut:
                loggedOutView
            case .waitingForUserCode(let code, let url):
                deviceCodeView(code: code, url: url)
            case .polling:
                pollingView
            case .loggedIn(let username, _):
                loggedInView(username: username)
            case .error(let message):
                errorView(message: message)
            }

            Spacer()
        }
        .padding(AnvilSpacing.xxl)
        .frame(width: 400, height: 380)
        .background(.regularMaterial)
    }

    // MARK: - States

    private var loggedOutView: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Text("Sign in with GitHub to access pull requests, issues, and CI status.")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
                .multilineTextAlignment(.center)

            AnvilButton("Sign in with GitHub", icon: "arrow.right.circle", style: .cta) {
                viewModel.startLogin()
            }
        }
    }

    private func deviceCodeView(code: String, url: String) -> some View {
        VStack(spacing: AnvilSpacing.lg) {
            Text("Enter this code on GitHub:")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)

            // Big user code
            Text(code)
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundStyle(AnvilColor.textPrimary)
                .padding(.horizontal, AnvilSpacing.xl)
                .padding(.vertical, AnvilSpacing.md)
                .background(AnvilColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .textSelection(.enabled)

            HStack(spacing: AnvilSpacing.sm) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text("Copy code")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)

                Button {
                    if let nsURL = URL(string: url) {
                        NSWorkspace.shared.open(nsURL)
                    }
                } label: {
                    HStack(spacing: AnvilSpacing.xxs) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                        Text("Open GitHub")
                            .font(AnvilFont.label)
                    }
                    .foregroundStyle(AnvilColor.accentBlue)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: AnvilSpacing.xs) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for authorization...")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Button("Cancel") {
                viewModel.cancelLogin()
            }
            .buttonStyle(.plain)
            .font(AnvilFont.label)
            .foregroundStyle(AnvilColor.textTertiary)
        }
    }

    private var pollingView: some View {
        VStack(spacing: AnvilSpacing.md) {
            ProgressView()
                .controlSize(.regular)
            Text("Validating credentials...")
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
        }
    }

    private func loggedInView(username: String) -> some View {
        VStack(spacing: AnvilSpacing.lg) {
            HStack(spacing: AnvilSpacing.sm) {
                Circle()
                    .fill(AnvilColor.accentGreen.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AnvilColor.accentGreen)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Signed in as")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                    Text(username)
                        .font(AnvilFont.body)
                        .foregroundStyle(AnvilColor.textPrimary)
                        .fontWeight(.medium)
                }
            }

            HStack(spacing: AnvilSpacing.md) {
                AnvilButton("Done", style: .primary) {
                    dismiss()
                }

                Button("Sign out") {
                    viewModel.logout {
                        container.resetGitHubAdapter()
                    }
                }
                .buttonStyle(.plain)
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.accentRed)
            }
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: AnvilSpacing.lg) {
            HStack(spacing: AnvilSpacing.xs) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                Text(message)
                    .font(AnvilFont.body)
                    .lineLimit(3)
            }
            .foregroundStyle(AnvilColor.accentRed)

            AnvilButton("Try Again", icon: "arrow.clockwise", style: .secondary) {
                viewModel.retryLogin()
            }
        }
    }
}
