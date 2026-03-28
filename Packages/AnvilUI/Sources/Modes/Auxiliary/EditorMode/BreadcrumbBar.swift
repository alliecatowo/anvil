import SwiftUI

struct BreadcrumbBar: View {
    @ObservedObject var viewModel: EditorViewModel

    @State private var activePopoverIndex: Int?

    var body: some View {
        HStack(spacing: 0) {
            if let file = viewModel.selectedFile {
                breadcrumbs(for: file)
            } else {
                Text("No file selected")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Cursor position indicator
            if viewModel.selectedFile != nil {
                Text("Ln \(viewModel.cursorLine), Col \(viewModel.cursorColumn)")
                    .font(AnvilFont.label)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, AnvilSpacing.sm)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: 28)
        .background(.bar)
    }

    // MARK: - Breadcrumbs

    @ViewBuilder
    private func breadcrumbs(for file: EditorFile) -> some View {
        let components = file.pathComponents

        HStack(spacing: AnvilSpacing.xxxs) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    chevron
                }

                let isLast = index == components.count - 1

                pathSegment(component, index: index, isLast: isLast, components: components)
            }

            // Symbol breadcrumb (function/class at cursor)
            if let symbol = viewModel.symbolAtCursor {
                chevron

                symbolSegment(symbol)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.tertiary)
    }

    // MARK: - Path Segment with Dropdown

    private func pathSegment(_ name: String, index: Int, isLast: Bool, components: [String]) -> some View {
        Button {
            activePopoverIndex = activePopoverIndex == index ? nil : index
        } label: {
            HStack(spacing: AnvilSpacing.xxxs) {
                if isLast {
                    Image(systemName: fileIcon(for: name))
                        .font(.system(size: 10))
                        .foregroundStyle(fileColor(for: name))
                }

                Text(name)
                    .font(AnvilFont.label)
                    .foregroundStyle(
                        isLast ? .primary : .secondary
                    )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                activePopoverIndex == index
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 4)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: Binding(
            get: { activePopoverIndex == index },
            set: { if !$0 { activePopoverIndex = nil } }
        ), arrowEdge: .bottom) {
            siblingDropdown(components: components, level: index)
        }
    }

    // MARK: - Symbol Segment

    private func symbolSegment(_ symbol: EditorSymbol) -> some View {
        Menu {
            ForEach(viewModel.symbols) { sym in
                Button {
                    viewModel.navigateToSymbol(sym)
                } label: {
                    Label(sym.name, systemImage: sym.kind.icon)
                }
            }
        } label: {
            HStack(spacing: AnvilSpacing.xxxs) {
                Image(systemName: symbol.kind.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(symbol.kind.color)

                Text(symbol.name)
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.accentBlue)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    // MARK: - Sibling Dropdown

    private func siblingDropdown(components: [String], level: Int) -> some View {
        let siblings = viewModel.siblingsAtPathLevel(components, level: level)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if siblings.isEmpty {
                    Text("No items")
                        .font(AnvilFont.label)
                        .foregroundStyle(.tertiary)
                        .padding(AnvilSpacing.sm)
                } else {
                    ForEach(siblings) { node in
                        Button {
                            if let path = node.filePath {
                                viewModel.openFileFromTree(path)
                            }
                            activePopoverIndex = nil
                        } label: {
                            HStack(spacing: AnvilSpacing.xs) {
                                Image(systemName: node.isFolder ? "folder.fill" : fileIcon(for: node.name))
                                    .font(.system(size: 12))
                                    .foregroundStyle(node.isFolder ? AnvilColor.accentBlue : fileColor(for: node.name))
                                    .frame(width: 16)

                                Text(node.name)
                                    .font(AnvilFont.label)
                                    .foregroundStyle(
                                        node.name == (level < components.count ? components[level] : "")
                                            ? AnvilColor.accentBlue
                                            : .primary
                                    )

                                Spacer()
                            }
                            .padding(.horizontal, AnvilSpacing.sm)
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            node.name == (level < components.count ? components[level] : "")
                                ? AnvilColor.accentBlue.opacity(0.08)
                                : Color.clear
                        )
                    }
                }
            }
        }
        .frame(width: 200)
        .frame(maxHeight: 300)
    }

    // MARK: - Helpers

    private func fileIcon(for name: String) -> String {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "swift"
        case "ts", "tsx": return "t.square"
        case "js", "jsx": return "j.square"
        case "py": return "p.square"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        case "yml", "yaml": return "gearshape"
        case "html": return "globe"
        case "css": return "paintbrush"
        default: return "doc"
        }
    }

    private func fileColor(for name: String) -> Color {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return AnvilColor.accentRed
        case "ts", "tsx": return AnvilColor.accentBlue
        case "js", "jsx": return AnvilColor.accentAmber
        case "py": return AnvilColor.accentGreen
        case "md": return AnvilColor.accentBlue
        case "json": return AnvilColor.accentAmber
        default: return Color.secondary
        }
    }
}
