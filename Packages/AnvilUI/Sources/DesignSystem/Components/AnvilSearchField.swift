import SwiftUI

public struct AnvilSearchField: View {
    @Binding var text: String
    let placeholder: String

    public init(text: Binding<String>, placeholder: String = "Search...") {
        self._text = text
        self.placeholder = placeholder
    }

    public var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(AnvilColor.textTertiary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AnvilFont.commandPaletteInput)
                .foregroundStyle(AnvilColor.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(AnvilColor.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
    }
}
