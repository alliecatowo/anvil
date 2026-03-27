import SwiftUI

// MARK: - Models

struct TerminalTab: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    var lines: [TerminalLine]
}

struct TerminalLine: Identifiable {
    let id = UUID()
    let content: String
    let style: TerminalLineStyle
}

enum TerminalLineStyle {
    case prompt
    case output
    case error
    case success
    case comment

    var color: Color {
        switch self {
        case .prompt: AnvilColor.accentGreen
        case .output: AnvilColor.textSecondary
        case .error: AnvilColor.accentRed
        case .success: AnvilColor.accentGreen
        case .comment: AnvilColor.textTertiary
        }
    }
}

// MARK: - ViewModel

@MainActor
class TerminalViewModel: ObservableObject {
    @Published var tabs: [TerminalTab] = []
    @Published var selectedTabId: UUID?
    @Published var inputText: String = ""

    var selectedTab: TerminalTab? {
        tabs.first { $0.id == selectedTabId }
    }

    init() {
        let zshTab = TerminalTab(name: "zsh", icon: "terminal", lines: [
            TerminalLine(content: "~ $ cd ~/Projects/anvil", style: .prompt),
            TerminalLine(content: "~/Projects/anvil $ swift build", style: .prompt),
            TerminalLine(content: "Building for debugging...", style: .output),
            TerminalLine(content: "Compiling AnvilDomain (42 sources)...", style: .output),
            TerminalLine(content: "Compiling AnvilEngine (35 sources)...", style: .output),
            TerminalLine(content: "Compiling AnvilUI (141 sources)...", style: .output),
            TerminalLine(content: "Build complete! (12.4s)", style: .success),
            TerminalLine(content: "~/Projects/anvil $ git status", style: .prompt),
            TerminalLine(content: "On branch feature/auxiliary-modes", style: .output),
            TerminalLine(content: "Changes not staged for commit:", style: .output),
            TerminalLine(content: "  modified:   Packages/AnvilUI/Sources/Shell/ContentArea.swift", style: .output),
            TerminalLine(content: "", style: .output),
            TerminalLine(content: "Untracked files:", style: .output),
            TerminalLine(content: "  Packages/AnvilUI/Sources/Modes/Auxiliary/DatabaseMode/", style: .output),
            TerminalLine(content: "  Packages/AnvilUI/Sources/Modes/Auxiliary/TerminalMode/", style: .output),
            TerminalLine(content: "~/Projects/anvil $", style: .prompt),
        ])

        let nodeTab = TerminalTab(name: "node", icon: "chevron.left.forwardslash.chevron.right", lines: [
            TerminalLine(content: "~ $ node --version", style: .prompt),
            TerminalLine(content: "v20.11.0", style: .output),
            TerminalLine(content: "~ $ node", style: .prompt),
            TerminalLine(content: "Welcome to Node.js v20.11.0.", style: .output),
            TerminalLine(content: "> console.log('hello from node')", style: .prompt),
            TerminalLine(content: "hello from node", style: .output),
            TerminalLine(content: "undefined", style: .comment),
            TerminalLine(content: ">", style: .prompt),
        ])

        let dockerTab = TerminalTab(name: "docker", icon: "shippingbox", lines: [
            TerminalLine(content: "~ $ docker ps", style: .prompt),
            TerminalLine(content: "CONTAINER ID   IMAGE          STATUS          PORTS", style: .output),
            TerminalLine(content: "a1b2c3d4e5f6   postgres:16    Up 2 hours      5432/tcp", style: .output),
            TerminalLine(content: "f6e5d4c3b2a1   redis:7        Up 2 hours      6379/tcp", style: .output),
            TerminalLine(content: "~ $ docker logs a1b2c3d4e5f6 --tail 3", style: .prompt),
            TerminalLine(content: "LOG:  database system is ready to accept connections", style: .output),
            TerminalLine(content: "LOG:  autovacuum launcher started", style: .output),
            TerminalLine(content: "LOG:  listening on IPv4 address \"0.0.0.0\", port 5432", style: .success),
            TerminalLine(content: "~ $", style: .prompt),
        ])

        tabs = [zshTab, nodeTab, dockerTab]
        selectedTabId = zshTab.id
    }

    // MARK: - Actions

    func selectTab(_ id: UUID) {
        selectedTabId = id
    }

    func submitInput() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let index = tabs.firstIndex(where: { $0.id == selectedTabId }) else { return }

        let promptLine = TerminalLine(content: "$ \(inputText)", style: .prompt)
        tabs[index].lines.append(promptLine)

        let responseLine = TerminalLine(content: "command not found: \(inputText)", style: .error)
        tabs[index].lines.append(responseLine)

        inputText = ""
    }

    func addTab() {
        let tab = TerminalTab(name: "zsh", icon: "terminal", lines: [
            TerminalLine(content: "~ $", style: .prompt),
        ])
        tabs.append(tab)
        selectedTabId = tab.id
    }

    func closeTab(_ id: UUID) {
        tabs.removeAll { $0.id == id }
        if selectedTabId == id {
            selectedTabId = tabs.first?.id
        }
    }
}
