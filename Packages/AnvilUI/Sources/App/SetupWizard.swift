import SwiftUI

public struct SetupWizard: View {
    @StateObject private var viewModel = SetupWizardViewModel()
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var appState: AppState
    let onComplete: () -> Void

    public init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        ZStack {
            AnvilColor.backgroundPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Step indicator
                if viewModel.currentStep != .welcome {
                    stepIndicator
                        .padding(.top, AnvilSpacing.xxl)
                }

                Spacer()

                // Content area — fixed width, centered
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        welcomeStep
                    case .detectEnvironment:
                        detectEnvironmentStep
                    case .configureACP:
                        configureACPStep
                    case .openProject:
                        openProjectStep
                    case .ready:
                        readyStep
                    }
                }
                .frame(width: 600)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)

                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: AnvilSpacing.md) {
            ForEach(SetupStep.allCases, id: \.rawValue) { step in
                if step != .welcome {
                    Circle()
                        .fill(step.rawValue <= viewModel.currentStep.rawValue
                              ? AnvilColor.accentPurple
                              : AnvilColor.borderMedium)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }

    // MARK: - Step 1: Welcome

    private var welcomeStep: some View {
        VStack(spacing: AnvilSpacing.xxl) {
            Spacer()

            // Logo placeholder
            Image(systemName: "hammer.fill")
                .font(.system(size: 72, weight: .light))
                .foregroundStyle(AnvilColor.accentPurple)
                .shadow(color: AnvilColor.accentPurple.opacity(0.4), radius: 24, y: 8)

            VStack(spacing: AnvilSpacing.md) {
                Text("Welcome to Anvil")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(AnvilColor.textPrimary)

                Text("The post-IDE. Agent-native development for macOS.")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            Spacer()

            Button(action: {
                withAnimation { viewModel.goNext() }
            }) {
                Text("Get Started")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 44)
                    .background(AnvilColor.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(AnvilSpacing.xxxl)
    }

    // MARK: - Step 2: Detect Environment

    private var detectEnvironmentStep: some View {
        VStack(spacing: AnvilSpacing.xxl) {
            VStack(spacing: AnvilSpacing.sm) {
                Text("Your Environment")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text("Scanning for developer tools on your machine.")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            VStack(spacing: AnvilSpacing.sm) {
                ForEach(viewModel.detectedTools) { tool in
                    toolRow(tool)
                }
            }

            if !viewModel.isScanning {
                Text(viewModel.environmentSummary)
                    .font(AnvilFont.body)
                    .foregroundStyle(
                        viewModel.detectedTools.contains(where: { $0.isRequired && !$0.isInstalled })
                        ? AnvilColor.accentAmber
                        : AnvilColor.accentGreen
                    )
                    .multilineTextAlignment(.center)
            }

            Spacer().frame(height: AnvilSpacing.lg)

            navigationButtons(
                backAction: { withAnimation { viewModel.goBack() } },
                nextAction: { withAnimation { viewModel.goNext() } },
                nextLabel: "Continue"
            )
        }
        .padding(AnvilSpacing.xxxl)
        .task {
            await viewModel.scanEnvironment()
        }
    }

    private func toolRow(_ tool: DetectedTool) -> some View {
        AnvilCard {
            HStack(spacing: AnvilSpacing.md) {
                Image(systemName: tool.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(AnvilColor.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AnvilSpacing.xs) {
                        Text(tool.name)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textPrimary)
                        if tool.isRequired {
                            Text("required")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AnvilColor.accentAmber)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AnvilColor.accentAmber.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    if let version = tool.version {
                        Text(version)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                    if let path = tool.path {
                        Text(path)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if viewModel.isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    statusIcon(installed: tool.isInstalled, required: tool.isRequired)
                }
            }
        }
    }

    private func statusIcon(installed: Bool, required: Bool) -> some View {
        Group {
            if installed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AnvilColor.accentGreen)
            } else if required {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AnvilColor.accentAmber)
            } else {
                Image(systemName: "minus.circle")
                    .foregroundStyle(AnvilColor.textTertiary)
            }
        }
        .font(.system(size: 18))
    }

    // MARK: - Step 3: Configure ACP

    private var configureACPStep: some View {
        VStack(spacing: AnvilSpacing.xxl) {
            VStack(spacing: AnvilSpacing.sm) {
                Text("Connect to AI")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text("How would you like to connect to AI?")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            VStack(spacing: AnvilSpacing.sm) {
                ForEach(ACPProviderOption.allCases) { option in
                    providerCard(option)
                }
            }

            // Inline config for the selected provider
            if viewModel.selectedProvider.needsAPIKey {
                SecureField("API Key", text: $viewModel.apiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textPrimary)
            }

            if viewModel.selectedProvider.needsURL {
                AnvilTextField("Ollama URL", text: $viewModel.ollamaURL, icon: "link")
            }

            // Test connection button + result
            HStack(spacing: AnvilSpacing.md) {
                Button(action: {
                    Task { await viewModel.testConnection() }
                }) {
                    HStack(spacing: AnvilSpacing.xs) {
                        if case .testing = viewModel.connectionTestResult {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("Test Connection")
                            .font(AnvilFont.body)
                    }
                    .foregroundStyle(AnvilColor.textPrimary)
                    .padding(.horizontal, AnvilSpacing.md)
                    .padding(.vertical, AnvilSpacing.xs)
                    .background(AnvilColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AnvilColor.borderMedium, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                connectionTestLabel
            }

            Spacer().frame(height: AnvilSpacing.sm)

            navigationButtons(
                backAction: { withAnimation { viewModel.goBack() } },
                nextAction: { withAnimation { viewModel.goNext() } },
                nextLabel: "Continue",
                nextDisabled: !viewModel.canProceedFromACP
            )
        }
        .padding(AnvilSpacing.xxxl)
    }

    private func providerCard(_ option: ACPProviderOption) -> some View {
        let isSelected = viewModel.selectedProvider == option
        let claudeDetected = viewModel.detectedTools.first(where: { $0.id == "claude" })?.isInstalled == true

        return Button(action: {
            viewModel.selectedProvider = option
            viewModel.connectionTestResult = .idle
        }) {
            HStack(spacing: AnvilSpacing.md) {
                Image(systemName: option.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? AnvilColor.accentPurple : AnvilColor.textSecondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AnvilSpacing.xs) {
                        Text(option.displayName)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textPrimary)
                        if option == .claudeCLI && claudeDetected {
                            Text("recommended")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AnvilColor.accentGreen)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AnvilColor.accentGreen.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text(option.subtitle)
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                Spacer()

                Circle()
                    .strokeBorder(isSelected ? AnvilColor.accentPurple : AnvilColor.borderMedium, lineWidth: 2)
                    .background(Circle().fill(isSelected ? AnvilColor.accentPurple : Color.clear))
                    .frame(width: 16, height: 16)
            }
            .padding(AnvilSpacing.cardPadding)
            .background(isSelected ? AnvilColor.accentPurple.opacity(0.08) : AnvilColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(isSelected ? AnvilColor.accentPurple.opacity(0.5) : AnvilColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var connectionTestLabel: some View {
        switch viewModel.connectionTestResult {
        case .idle:
            EmptyView()
        case .testing:
            EmptyView()
        case .success:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.accentGreen)
        case .failure(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(AnvilFont.label)
                .foregroundStyle(AnvilColor.accentRed)
        }
    }

    // MARK: - Step 4: Open Project

    private var openProjectStep: some View {
        VStack(spacing: AnvilSpacing.xxl) {
            VStack(spacing: AnvilSpacing.sm) {
                Text("Open a Project")
                    .font(AnvilFont.heading)
                    .foregroundStyle(AnvilColor.textPrimary)
                Text("Choose how you'd like to get started.")
                    .font(AnvilFont.body)
                    .foregroundStyle(AnvilColor.textSecondary)
            }

            VStack(spacing: AnvilSpacing.sm) {
                // Open Existing
                projectOptionCard(
                    option: .openExisting,
                    icon: "folder",
                    title: "Open Existing",
                    subtitle: "Open a project folder from your machine"
                ) {
                    if viewModel.projectSetupOption == .openExisting {
                        HStack(spacing: AnvilSpacing.sm) {
                            Text(viewModel.selectedProjectPath ?? "No folder selected")
                                .font(AnvilFont.label)
                                .foregroundStyle(viewModel.selectedProjectPath != nil
                                                 ? AnvilColor.textPrimary
                                                 : AnvilColor.textTertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            Spacer()

                            Button("Browse...") {
                                viewModel.openDirectoryPicker()
                            }
                            .font(AnvilFont.label)
                            .buttonStyle(.plain)
                            .foregroundStyle(AnvilColor.accentPurple)
                        }
                        .padding(.top, AnvilSpacing.xs)
                    }
                }

                // Clone Repository
                projectOptionCard(
                    option: .cloneRepository,
                    icon: "arrow.down.circle",
                    title: "Clone Repository",
                    subtitle: "Clone a Git repository by URL"
                ) {
                    if viewModel.projectSetupOption == .cloneRepository {
                        AnvilTextField("https://github.com/...", text: $viewModel.cloneURL, icon: "link")
                            .padding(.top, AnvilSpacing.xs)
                    }
                }

                // Start Fresh
                projectOptionCard(
                    option: .startFresh,
                    icon: "plus.square",
                    title: "Start Fresh",
                    subtitle: "Create a new project with git init"
                ) {
                    if viewModel.projectSetupOption == .startFresh {
                        AnvilTextField("Project name", text: $viewModel.newProjectName, icon: "pencil")
                            .padding(.top, AnvilSpacing.xs)
                    }
                }
            }

            Spacer().frame(height: AnvilSpacing.sm)

            navigationButtons(
                backAction: { withAnimation { viewModel.goBack() } },
                nextAction: {
                    Task {
                        await viewModel.setupProject(container: container)
                        container.configureProvider(viewModel.buildProviderConfig())
                        withAnimation { viewModel.goNext() }
                    }
                },
                nextLabel: "Continue",
                nextDisabled: !viewModel.canProceedFromProject
            )
        }
        .padding(AnvilSpacing.xxxl)
    }

    private func projectOptionCard<Content: View>(
        option: ProjectSetupOption,
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isSelected = viewModel.projectSetupOption == option

        return Button(action: {
            viewModel.projectSetupOption = option
        }) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: AnvilSpacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(isSelected ? AnvilColor.accentPurple : AnvilColor.textSecondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(AnvilFont.body)
                            .foregroundStyle(AnvilColor.textPrimary)
                        Text(subtitle)
                            .font(AnvilFont.label)
                            .foregroundStyle(AnvilColor.textTertiary)
                    }

                    Spacer()

                    Circle()
                        .strokeBorder(isSelected ? AnvilColor.accentPurple : AnvilColor.borderMedium, lineWidth: 2)
                        .background(Circle().fill(isSelected ? AnvilColor.accentPurple : Color.clear))
                        .frame(width: 16, height: 16)
                }

                content()
            }
            .padding(AnvilSpacing.cardPadding)
            .background(isSelected ? AnvilColor.accentPurple.opacity(0.08) : AnvilColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius)
                    .stroke(isSelected ? AnvilColor.accentPurple.opacity(0.5) : AnvilColor.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 5: Ready

    private var readyStep: some View {
        VStack(spacing: AnvilSpacing.xxl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(AnvilColor.accentGreen)

            VStack(spacing: AnvilSpacing.md) {
                Text("You're all set.")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(AnvilColor.textPrimary)
            }

            // Summary checkmarks
            VStack(alignment: .leading, spacing: AnvilSpacing.md) {
                summaryRow(icon: "checkmark", text: "Environment scanned")
                summaryRow(icon: "checkmark", text: "AI provider configured (\(viewModel.selectedProvider.displayName))")
                if let path = viewModel.selectedProjectPath {
                    summaryRow(icon: "checkmark", text: "Project: \(URL(fileURLWithPath: path).lastPathComponent)")
                }
            }
            .padding(AnvilSpacing.xl)
            .background(AnvilColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))

            // Quick tips
            VStack(alignment: .leading, spacing: AnvilSpacing.sm) {
                Text("Quick Tips")
                    .font(AnvilFont.subheading)
                    .foregroundStyle(AnvilColor.textPrimary)

                tipRow(keys: "\u{2318}K", description: "for anything")
                tipRow(keys: "\u{2318}1-4", description: "for modes")
                tipRow(keys: "\u{2318}\u{21E7}A", description: "to start an agent")
            }
            .padding(AnvilSpacing.xl)
            .background(AnvilColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AnvilSpacing.cardCornerRadius))

            Spacer()

            Button(action: {
                SetupWizardViewModel.markSetupComplete()
                appState.switchSpace(.build)
                onComplete()
            }) {
                Text("Start Building")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 200, height: 44)
                    .background(AnvilColor.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(AnvilSpacing.xxxl)
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AnvilColor.accentGreen)
            Text(text)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
        }
    }

    private func tipRow(keys: String, description: String) -> some View {
        HStack(spacing: AnvilSpacing.sm) {
            Text(keys)
                .font(AnvilFont.code)
                .foregroundStyle(AnvilColor.accentPurple)
                .frame(width: 60, alignment: .trailing)
            Text(description)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textSecondary)
        }
    }

    // MARK: - Navigation Buttons

    private func navigationButtons(
        backAction: @escaping () -> Void,
        nextAction: @escaping () -> Void,
        nextLabel: String,
        nextDisabled: Bool = false
    ) -> some View {
        HStack {
            Button(action: backAction) {
                HStack(spacing: AnvilSpacing.xxs) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Back")
                        .font(AnvilFont.body)
                }
                .foregroundStyle(AnvilColor.textSecondary)
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.vertical, AnvilSpacing.xs)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: nextAction) {
                Text(nextLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, AnvilSpacing.xl)
                    .padding(.vertical, AnvilSpacing.sm)
                    .background(nextDisabled ? AnvilColor.borderMedium : AnvilColor.accentPurple)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(nextDisabled)
        }
    }
}
