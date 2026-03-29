import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers

// MARK: - Context Resolver

/// Data needed to resolve immediate context slash commands (/tab, /selection, /diff, /branch).
/// Passed into InputBar so it can inject context chips without needing AppState directly.
@MainActor
struct ContextSlashResolver {
    /// Returns the currently focused editor tab as a ContextAttachment, or nil if none.
    var resolveTab: () -> ContextAttachment?
    /// Returns the current editor selection as a ContextAttachment, or nil if none.
    var resolveSelection: () -> ContextAttachment?
    /// Returns the current git diff as a ContextAttachment, or nil if no changes.
    var resolveDiff: () -> ContextAttachment?
    /// Returns the current branch info as a ContextAttachment, or nil.
    var resolveBranch: () -> ContextAttachment?
    /// Returns available tickets as (id, title) tuples for the ticket picker.
    var availableTickets: () -> [(id: String, title: String)]

    static let empty = ContextSlashResolver(
        resolveTab: { nil },
        resolveSelection: { nil },
        resolveDiff: { nil },
        resolveBranch: { nil },
        availableTickets: { [] }
    )
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    let isRunning: Bool
    let queuedCount: Int
    let attachments: [ContextAttachment]
    let onSend: () -> Void
    let onRemoveAttachment: (String) -> Void
    let onAddAttachment: (ContextAttachment) -> Void
    var autoContextFiles: [AutoContextChipData] = []
    var onDismissAutoContext: ((String) -> Void)?
    var onAcceptAutoContext: ((String) -> Void)?
    var contextResolver: ContextSlashResolver = .empty

    @State private var showSlashMenu = false
    @State private var showAtPopup = false
    @State private var isDropTargeted = false
    @State private var isAutoContextExpanded = false
    @State private var showFilePicker = false
    @State private var showTicketPicker = false
    @State private var pickerFilter = ""
    @State private var projectFiles: [String] = []
    @State private var branches: [String] = []
    @State private var ticketIds: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Context attachment bar
            ContextAttachmentBar(attachments: attachments, onRemove: onRemoveAttachment)

            // Auto-context section (collapsed by default)
            if !autoContextFiles.isEmpty {
                AutoContextBar(
                    files: autoContextFiles,
                    isExpanded: $isAutoContextExpanded,
                    onDismiss: { path in onDismissAutoContext?(path) },
                    onAccept: { path in onAcceptAutoContext?(path) }
                )
            }

            // Slash command popup
            if showSlashMenu {
                HStack {
                    SlashCommandMenu(filter: text) { command in
                        handleSlashCommand(command)
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // File picker (shown after /file)
            if showFilePicker {
                HStack {
                    SlashFilePickerMenu(files: projectFiles, filter: pickerFilter) { path in
                        onAddAttachment(.file(path: path))
                        dismissPicker()
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Ticket picker (shown after /ticket)
            if showTicketPicker {
                HStack {
                    SlashTicketPickerMenu(
                        tickets: contextResolver.availableTickets(),
                        filter: pickerFilter
                    ) { id, title in
                        onAddAttachment(.ticket(id: id, title: title))
                        dismissPicker()
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // @ reference popup (two-level: categories then items)
            if showAtPopup {
                HStack {
                    AtReferencePopup(
                        filter: currentAtToken,
                        projectFiles: projectFiles,
                        branches: branches,
                        ticketIds: ticketIds
                    ) { attachment in
                        replaceCurrentAtToken(with: "")
                        onAddAttachment(attachment)
                        showAtPopup = false
                    }
                    Spacer()
                }
                .padding(.horizontal, AnvilSpacing.md)
                .padding(.bottom, AnvilSpacing.xs)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: AnvilSpacing.sm) {
                // Sparkles button for AI quick actions
                SparklesButton()

                TextField(isRunning ? "Queue next message..." : "Message the agent...", text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(AnvilFont.body)
                    .lineLimit(1...5)
                    .onSubmit(onSend)
                    .onChange(of: text) { _, newValue in
                        withAnimation(AnvilAnimation.standard) {
                            // Only show slash menu when not in a picker sub-mode
                            if !showFilePicker && !showTicketPicker {
                                showSlashMenu = newValue.hasPrefix("/") && !newValue.contains(" ")
                            } else {
                                // Update picker filter text
                                pickerFilter = newValue
                            }
                            showAtPopup = detectAtToken(in: newValue)
                        }
                    }
                    .onKeyPress(.escape) {
                        if showFilePicker || showTicketPicker {
                            dismissPicker()
                            return .handled
                        }
                        if showSlashMenu {
                            showSlashMenu = false
                            text = ""
                            return .handled
                        }
                        return .ignored
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityIdentifier("agent.conversation.input")

                if queuedCount > 0 {
                    Text("\(queuedCount) queued")
                        .font(AnvilFont.label)
                        .foregroundStyle(AnvilColor.accentAmber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AnvilColor.accentAmber.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                Button(action: onSend) {
                    Image(systemName: isRunning ? (text.isEmpty ? "pause.circle.fill" : "plus.circle.fill") : "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(text.isEmpty && !isRunning ? AnvilColor.textTertiary : AnvilColor.accentBlue)
                        .accessibilityHidden(true)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty && !isRunning)
                .help(isRunning && !text.isEmpty ? "Queue message" : "")
                .accessibilityLabel("Send message")
            }
            .padding(AnvilSpacing.md)
        }
        .overlay(
            Rectangle()
                .stroke(AnvilColor.accentBlue.opacity(isDropTargeted ? 0.6 : 0), lineWidth: 2)
        )
        .accessibilityLabel("Attach file")
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url {
                        Task { @MainActor in
                            onAddAttachment(.file(path: url.path))
                        }
                    }
                }
            }
            return true
        }
        .onAppear {
            projectFiles = InputBarHelpers.loadProjectFiles()
            branches = InputBarHelpers.loadBranches()
        }
    }

    // MARK: - Slash Command Handling

    private func handleSlashCommand(_ command: SlashCommand) {
        switch command.type {
        case .prompt(let template, let autoSend):
            text = template
            showSlashMenu = false
            if autoSend { onSend() }

        case .injectContext:
            showSlashMenu = false
            text = ""
            resolveImmediateContext(command.id)

        case .picker(let kind):
            showSlashMenu = false
            text = ""
            pickerFilter = ""
            withAnimation(AnvilAnimation.standard) {
                switch kind {
                case .file:
                    showFilePicker = true
                case .ticket:
                    showTicketPicker = true
                }
            }
        }
    }

    private func resolveImmediateContext(_ commandId: String) {
        let attachment: ContextAttachment?
        switch commandId {
        case "ctx-tab":
            attachment = contextResolver.resolveTab()
        case "ctx-selection":
            attachment = contextResolver.resolveSelection()
        case "ctx-diff":
            attachment = contextResolver.resolveDiff()
        case "ctx-branch":
            attachment = contextResolver.resolveBranch()
        default:
            attachment = nil
        }
        if let attachment {
            onAddAttachment(attachment)
        }
    }

    private func dismissPicker() {
        withAnimation(AnvilAnimation.standard) {
            showFilePicker = false
            showTicketPicker = false
            pickerFilter = ""
            text = ""
        }
    }

    // MARK: - @ token detection

    private var currentAtToken: String {
        guard let atRange = text.range(of: "@[^\\s]*$", options: .regularExpression) else { return "" }
        return String(text[atRange])
    }

    private func detectAtToken(in value: String) -> Bool {
        value.range(of: "@[^\\s]*$", options: .regularExpression) != nil
    }

    private func replaceCurrentAtToken(with replacement: String) {
        if let atRange = text.range(of: "@[^\\s]*$", options: .regularExpression) {
            var updated = text
            updated.replaceSubrange(atRange, with: replacement)
            text = updated
        }
    }
}

// MARK: - Input Bar Helpers

/// Static helpers for loading project context (files, branches) used by InputBar.
enum InputBarHelpers {
    /// List source files from the current working directory (shallow scan, common extensions).
    static func loadProjectFiles() -> [String] {
        let cwd = FileManager.default.currentDirectoryPath
        return listFiles(at: cwd, maxDepth: 3)
    }

    /// List git branches from the current working directory.
    static func loadBranches() -> [String] {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["branch", "--format=%(refname:short)"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [] }
            return output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    /// Load the current git diff (staged + unstaged).
    static func loadGitDiff() -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["diff", "HEAD"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return nil }
            return output
        } catch {
            return nil
        }
    }

    /// Load the current branch name.
    static func loadCurrentBranch() -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["rev-parse", "--abbrev-ref", "HEAD"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }

    /// Load recent commits for the current branch (last 5).
    static func loadRecentCommits(count: Int = 5) -> String? {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["log", "--oneline", "-\(count)"]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8), !output.isEmpty else { return nil }
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private static let sourceExtensions: Set<String> = [
        "swift", "ts", "tsx", "js", "jsx", "py", "rs", "go", "java", "kt",
        "c", "h", "cpp", "hpp", "m", "mm", "rb", "ex", "exs", "yaml", "yml",
        "json", "toml", "md", "txt", "html", "css", "scss"
    ]

    private static func listFiles(at path: String, maxDepth: Int, currentDepth: Int = 0) -> [String] {
        guard currentDepth < maxDepth else { return [] }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        var results: [String] = []
        for item in items {
            // Skip hidden dirs and common noise
            if item.hasPrefix(".") || item == "node_modules" || item == ".build" || item == "DerivedData" { continue }
            let full = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: full, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                results.append(contentsOf: listFiles(at: full, maxDepth: maxDepth, currentDepth: currentDepth + 1))
            } else {
                let ext = (item as NSString).pathExtension.lowercased()
                if sourceExtensions.contains(ext) {
                    results.append(full)
                }
            }
            if results.count >= 500 { break }
        }
        return results
    }
}

// MARK: - Sparkles Button

struct SparklesButton: View {
    @State private var isShowingMenu = false

    var body: some View {
        Menu {
            Button { } label: {
                Label("Review Current Branch", systemImage: "checkmark.circle")
            }
            Button { } label: {
                Label("Explain Selection", systemImage: "text.bubble")
            }
            Button { } label: {
                Label("Fix Current Error", systemImage: "wrench")
            }
            Button { } label: {
                Label("Generate Tests", systemImage: "testtube.2")
            }
            Divider()
            Button { } label: {
                Label("Auto-Commit", systemImage: "arrow.up.circle")
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AnvilColor.accentPurple)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("AI Actions")
    }
}
