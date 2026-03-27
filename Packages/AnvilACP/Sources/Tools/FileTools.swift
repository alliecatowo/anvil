import Foundation
import AnvilDomain

public enum FileTools {
    public static let readFile = ACPToolDefinition(
        name: "read_file",
        description: "Read the contents of a file at the given path",
        inputSchema: """
        {"type":"object","properties":{"path":{"type":"string","description":"Absolute file path"}},"required":["path"]}
        """
    )

    public static let writeFile = ACPToolDefinition(
        name: "write_file",
        description: "Write content to a file at the given path",
        inputSchema: """
        {"type":"object","properties":{"path":{"type":"string"},"content":{"type":"string"}},"required":["path","content"]}
        """
    )

    public static let searchFiles = ACPToolDefinition(
        name: "search_files",
        description: "Search for files matching a pattern",
        inputSchema: """
        {"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string"}},"required":["pattern"]}
        """
    )

    public static let grepContent = ACPToolDefinition(
        name: "grep",
        description: "Search file contents for a pattern",
        inputSchema: """
        {"type":"object","properties":{"pattern":{"type":"string"},"path":{"type":"string"},"type":{"type":"string"}},"required":["pattern"]}
        """
    )

    public static let all: [ACPToolDefinition] = [readFile, writeFile, searchFiles, grepContent]
}
