import SwiftUI

struct EditorTabBar: View {
    @ObservedObject var viewModel: EditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(viewModel.openFiles) { file in
                        tabItem(for: file)
                    }
                }
            }

            Spacer()
        }
        .frame(height: 34)
        .background(AnvilColor.backgroundSecondary)
    }

    // MARK: - Tab Item

    @State private var hoveredTabId: UUID?

    private func tabItem(for file: EditorFile) -> some View {
        let isSelected = viewModel.selectedFileId == file.id
        let isHovered = hoveredTabId == file.id

        let isReadOnly = viewModel.isFileReadOnly(file.id)

        return HStack(spacing: AnvilSpacing.xs) {
            Image(systemName: fileIcon(for: file.name))
                .font(.system(size: 11))
                .foregroundStyle(fileColor(for: file.name))
                .accessibilityHidden(true)

            Text(file.name)
                .font(AnvilFont.label)
                .foregroundStyle(isSelected ? AnvilColor.textPrimary : AnvilColor.textSecondary)
                .lineLimit(1)

            if isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .accessibilityLabel("Read-only")
            }

            Button {
                viewModel.closeFile(file.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(AnvilColor.textTertiary)
                    .frame(width: 14, height: 14)
                    .background(
                        isHovered ? AnvilColor.backgroundTertiary : Color.clear,
                        in: RoundedRectangle(cornerRadius: 3)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(file.name)")
            .accessibilityAddTraits(.isButton)
            .opacity(isSelected || isHovered ? 1 : 0)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.xs)
        .background(
            isSelected
                ? AnvilColor.backgroundPrimary
                : AnvilColor.backgroundSecondary
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? AnvilColor.accentBlue : Color.clear)
                .frame(height: 2),
            alignment: .top
        )
        .overlay(
            Rectangle()
                .fill(AnvilColor.borderSubtle)
                .frame(width: 1),
            alignment: .trailing
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredTabId = hovering ? file.id : nil
        }
        .onTapGesture {
            viewModel.selectFile(file.id)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name)\(isReadOnly ? ", read-only" : "")\(isSelected ? ", selected" : "")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
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
