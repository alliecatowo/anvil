import SwiftUI

struct DocBrowser: View {
    @ObservedObject var viewModel: DocsViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("DOCUMENTS")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                    .tracking(0.3)

                Spacer()

                Button {
                    // New document action
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.sm)

            Divider().overlay(AnvilColor.borderSubtle)

            // Doc tree
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(flattenedTree) { entry in
                        docTreeRow(entry: entry)
                    }
                }
                .padding(.vertical, AnvilSpacing.xxs)
            }
        }
    }

    // MARK: - Flattened Tree

    private struct FlatDocEntry: Identifiable {
        let id: UUID
        let node: DocNode
        let depth: Int
    }

    private var flattenedTree: [FlatDocEntry] {
        var result: [FlatDocEntry] = []
        func walk(_ nodes: [DocNode], depth: Int) {
            for node in nodes {
                result.append(FlatDocEntry(id: node.id, node: node, depth: depth))
                if node.isFolder && viewModel.expandedFolderIds.contains(node.id) {
                    walk(node.children, depth: depth + 1)
                }
            }
        }
        walk(viewModel.docTree, depth: 0)
        return result
    }

    // MARK: - Tree Row

    private func docTreeRow(entry: FlatDocEntry) -> some View {
        let node = entry.node
        let isExpanded = viewModel.expandedFolderIds.contains(node.id)
        let isSelected = viewModel.selectedDocId == node.id

        return HStack(spacing: AnvilSpacing.xxs) {
            Spacer().frame(width: CGFloat(entry.depth) * 16)

            if node.isFolder {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 12)
            } else {
                Spacer().frame(width: 12)
            }

            Image(systemName: node.isFolder ? (isExpanded ? "folder.fill" : "folder") : "doc.richtext")
                .font(.system(size: 12))
                .foregroundStyle(node.isFolder ? AnvilColor.accentAmber : AnvilColor.accentBlue)
                .frame(width: 16)

            Text(node.name)
                .font(AnvilFont.code)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, AnvilSpacing.sm)
        .frame(height: 24)
        .background(isSelected ? AnvilColor.selectionBackground : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if node.isFolder {
                viewModel.toggleFolder(node.id)
            } else {
                viewModel.selectDoc(node.id)
            }
        }
    }
}
