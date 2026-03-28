import SwiftUI
import AnvilDomain
import UniformTypeIdentifiers

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String
    let isRunning: Bool
    let queuedCount: Int
    let attachments: [ContextAttachment]
    let onSend: () -> Void
    let onRemoveAttachment: (String) -> Void
    let onAddAttachment: (ContextAttachment) -> Void

    @State private var showSlashMenu = false
    @State private var showAtPopup = false
    @State private var isDropTargeted = false
    @State private var projectFiles: [String] = []
    @State private var branches: [String] = []
    @State private var ticketIds: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            // Context attachment bar
            ContextAttachmentBar(attachments: attachments, onRemove: onRemoveAttachment)

            // Slash command popup
            if showSlashMenu {
                HStack {
                    SlashCommandMenu(filter: text) { command in
                        if command.autoSend {
                            text = command.promptTemplate
                            showSlashMenu = false
                            onSend()
                        } else {
                            text = command.promptTemplate
                            showSlashMenu = false
                        }
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
                            showSlashMenu = newValue.hasPrefix("/") && !newValue.contains(" ")
                            showAtPopup = detectAtToken(in: newValue)
                        }
                    }
                    .accessibilityLabel("Message input")

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
