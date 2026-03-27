import Foundation
import AnvilDomain

public enum TerminalTools {
    public static let execute = ACPToolDefinition(
        name: "terminal",
        description: "Execute a shell command and return its output",
        inputSchema: """
        {"type":"object","properties":{"command":{"type":"string","description":"Shell command to execute"},"timeout":{"type":"number","description":"Timeout in ms"}},"required":["command"]}
        """
    )

    public static let all: [ACPToolDefinition] = [execute]
}
