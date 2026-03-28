import SwiftUI

struct EditorSidebar: View {
    @ObservedObject var viewModel: EditorViewModel

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

        return HStack(spacing: AnvilSpacing.xxs) {
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
        }
        .frame(height: 24)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(node.isFolder ? "Folder: \(node.name)" : "\(node.name), \(fileTypeDescription(for: node.name))")
        .accessibilityAddTraits(node.isFolder ? .isButton : .isStaticText)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        .onTapGesture {
            if node.isFolder {
                viewModel.toggleFolder(node.id)
            } else if let path = node.filePath {
                viewModel.openFileFromTree(path)
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
