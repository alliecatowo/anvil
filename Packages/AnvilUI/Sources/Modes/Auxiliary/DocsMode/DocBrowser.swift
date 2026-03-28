import SwiftUI

struct DocBrowser: View {
    @ObservedObject var viewModel: DocsViewModel

    var body: some View {
        List {
            ForEach(flattenedTree) { entry in
                docTreeRow(entry: entry)
                    .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 8))
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            HStack {
                Text("Documents")
                    .font(AnvilFont.subheading)
                Spacer()
                Button("New", systemImage: "plus") {
                    viewModel.showNewDocSheet = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("New Document")
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)
            .background(.bar)
        }
        .sheet(isPresented: $viewModel.showNewDocSheet) {
            newDocumentSheet
        }
    }

    // MARK: - New Document Sheet

    private var newDocumentSheet: some View {
        VStack(spacing: AnvilSpacing.lg) {
            Text("New Document")
                .font(AnvilFont.heading)
                .foregroundStyle(AnvilColor.textPrimary)

            TextField("Document name", text: $viewModel.newDocName)
                .textFieldStyle(.roundedBorder)
                .font(AnvilFont.body)
                .onSubmit {
                    viewModel.createNewDocument()
                }

            HStack {
                Button("Cancel") {
                    viewModel.newDocName = ""
                    viewModel.showNewDocSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    viewModel.createNewDocument()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.newDocName.isEmpty)
            }
        }
        .padding(AnvilSpacing.xl)
        .frame(width: 360)
    }

    // MARK: - Flattened Tree

    private struct FlatDocEntry: Identifiable {
        let id: String
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
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)

            Spacer()
        }
        .frame(height: 24)
        .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
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
