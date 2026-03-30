import AppKit
import SwiftUI

struct EditorSidebar: View {
    @ObservedObject var viewModel: EditorViewModel
    @EnvironmentObject private var deps: DependencyContainer

    @State private var renamingNodeId: UUID?
    @State private var renameText: String = ""
    @State private var newFileName: String = ""
    @State private var creatingFileInFolder: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Explorer")
                    .font(.headline)

                Spacer()

                Button {
                    // Collapse all folders
                    viewModel.expandedFolders.removeAll()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse all folders")
                .accessibilityAddTraits(.isButton)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider()

            // File tree
            List {
                ForEach(flattenedTree) { entry in
                    fileTreeRow(entry: entry)
                        .listRowInsets(EdgeInsets(top: 0, leading: CGFloat(entry.depth) * 16 + 4, bottom: 0, trailing: 4))
                }
            }
            .listStyle(.sidebar)
        }
        .alert("Rename", isPresented: Binding(
            get: { renamingNodeId != nil },
            set: { if !$0 { renamingNodeId = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let nodeId = renamingNodeId,
                   let entry = flattenedTree.first(where: { $0.id == nodeId }),
                   let path = entry.node.filePath,
                   !renameText.isEmpty {
                    viewModel.renameFileOrFolder(atPath: path, to: renameText, using: deps.fileSystemService)
                }
                renamingNodeId = nil
            }
            Button("Cancel", role: .cancel) {
                renamingNodeId = nil
            }
        }
        .alert("New File", isPresented: Binding(
            get: { creatingFileInFolder != nil },
            set: { if !$0 { creatingFileInFolder = nil } }
        )) {
            TextField("Filename", text: $newFileName)
            Button("Create") {
                if let folderId = creatingFileInFolder,
                   let entry = flattenedTree.first(where: { $0.id == folderId }),
                   let dirPath = entry.node.filePath,
                   !newFileName.isEmpty {
                    viewModel.createNewFile(inDirectory: dirPath, name: newFileName, using: deps.fileSystemService)
                }
                creatingFileInFolder = nil
            }
            Button("Cancel", role: .cancel) {
                creatingFileInFolder = nil
            }
        }
    }

    // MARK: - Flattened Tree

    private struct FlatTreeEntry: Identifiable {
        let id: UUID
        let node: FileTreeNode
        let depth: Int
    }

    private var flattenedTree: [FlatTreeEntry] {
        var result: [FlatTreeEntry] = []
        func walk(_ nodes: [FileTreeNode], depth: Int) {
            for node in nodes {
                result.append(FlatTreeEntry(id: node.id, node: node, depth: depth))
                if node.isFolder && viewModel.expandedFolders.contains(node.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(viewModel.fileTree, depth: 0)
        return result
    }

    // MARK: - Tree Row

    private func fileTreeRow(entry: FlatTreeEntry) -> some View {
        let node = entry.node
        let isExpanded = viewModel.expandedFolders.contains(node.id)
        let isSelected = node.filePath != nil
            && viewModel.selectedFile?.path == node.filePath

        return Button {
            if node.isFolder {
                viewModel.toggleFolder(node.id)
            } else if let path = node.filePath {
                viewModel.openFileFromTree(path)
            }
        } label: {
            HStack(spacing: AnvilSpacing.xxs) {
                // Disclosure indicator for folders
                if node.isFolder {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 12)
                        .accessibilityHidden(true)
                } else {
                    Spacer().frame(width: 12)
                }

                // Icon
                Image(systemName: node.isFolder ? (isExpanded ? "folder.fill" : "folder") : fileIcon(for: node.name))
                    .font(.system(size: 12))
                    .foregroundStyle(node.isFolder ? AnvilColor.accentAmber : fileColor(for: node.name))
                    .frame(width: 16)
                    .accessibilityHidden(true)

                // Name
                Text(node.name)
                    .font(AnvilFont.code)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)

                Spacer()

                // Diagnostic count badges
                if !node.isFolder, let path = node.filePath {
                    let counts = viewModel.diagnosticCount(forPath: path)
                    if counts.errors > 0 {
                        Text("\(counts.errors)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentRed)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(counts.errors) errors")
                    }
                    if counts.warnings > 0 {
                        Text("\(counts.warnings)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(AnvilColor.accentAmber)
                            .clipShape(Capsule())
                            .accessibilityLabel("\(counts.warnings) warnings")
                    }
                }
            }
            .frame(height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(node.isFolder ? "Folder: \(node.name)" : "\(node.name), \(fileTypeDescription(for: node.name))")
        .accessibilityAddTraits(.isButton)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .contextMenu {
            fileContextMenu(for: node)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func fileContextMenu(for node: FileTreeNode) -> some View {
        if node.isFolder {
            Button("New File...") {
                creatingFileInFolder = node.id
                newFileName = "untitled.swift"
                // Expand the folder so the user sees the new file
                if !viewModel.expandedFolders.contains(node.id) {
                    viewModel.toggleFolder(node.id)
                }
            }
        }

        if let path = node.filePath {
            if !node.isFolder {
                Button("Open") {
                    viewModel.openFileFromTree(path)
                }
            }

            Divider()

            Button("Rename...") {
                renamingNodeId = node.id
                renameText = node.name
            }

            Button("Delete", role: .destructive) {
                viewModel.deleteFileOrFolder(atPath: path, using: deps.fileSystemService)
            }

            Divider()

            Button("Reveal in Finder") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }

            Button("Copy Relative Path") {
                let relPath: String
                if let root = deps.currentProjectPath, path.hasPrefix(root) {
                    var rel = String(path.dropFirst(root.count))
                    if rel.hasPrefix("/") { rel = String(rel.dropFirst()) }
                    relPath = rel
                } else {
                    relPath = path
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(relPath, forType: .string)
            }
        }
    }

    // MARK: - File Type Helpers

    private func fileTypeDescription(for name: String) -> String {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "Swift file"
        case "md": return "Markdown file"
        case "json": return "JSON file"
        case "yml", "yaml": return "YAML file"
        case "txt": return "Text file"
        default: return "file"
        }
    }

    private func fileIcon(for name: String) -> String {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "swift"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        case "yml", "yaml": return "list.bullet.indent"
        case "txt": return "doc.text"
        default: return "doc"
        }
    }

    private func fileColor(for name: String) -> Color {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return AnvilColor.accentRed
        case "md": return AnvilColor.accentBlue
        case "json": return AnvilColor.accentAmber
        case "yml", "yaml": return AnvilColor.accentPurple
        default: return Color.secondary
        }
    }
}
