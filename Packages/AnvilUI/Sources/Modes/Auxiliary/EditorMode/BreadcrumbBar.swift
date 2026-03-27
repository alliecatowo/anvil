import SwiftUI

struct BreadcrumbBar: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            if let file = viewModel.selectedFile {
                breadcrumbs(for: file)
            } else {
                Text("No file selected")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
            }

            Spacer()

            // Cursor position indicator
            if viewModel.selectedFile != nil {
                Text("Ln \(viewModel.cursorLine), Col \(viewModel.cursorColumn)")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textTertiary)
                    .padding(.trailing, AnvilSpacing.sm)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .frame(height: 28)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Breadcrumbs

    @ViewBuilder
    private func breadcrumbs(for file: EditorFile) -> some View {
        let components = file.pathComponents

        HStack(spacing: AnvilSpacing.xxxs) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AnvilColor.textTertiary)
                }

                let isLast = index == components.count - 1

                Button {
                    // Navigation is visual-only for now
                } label: {
                    HStack(spacing: AnvilSpacing.xxxs) {
                        if isLast {
                            Image(systemName: fileIcon(for: component))
                                .font(.system(size: 10))
                                .foregroundStyle(fileColor(for: component))
                        }

                        Text(component)
                            .font(AnvilFont.label)
                            .foregroundStyle(
                                isLast ? AnvilColor.textPrimary : AnvilColor.textSecondary
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func fileIcon(for name: String) -> String {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return "swift"
        case "md": return "doc.richtext"
        case "json": return "curlybraces"
        default: return "doc"
        }
    }

    private func fileColor(for name: String) -> Color {
        let ext = name.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "swift": return AnvilColor.accentRed
        case "md": return AnvilColor.accentBlue
        case "json": return AnvilColor.accentAmber
        default: return AnvilColor.textTertiary
        }
    }
}
