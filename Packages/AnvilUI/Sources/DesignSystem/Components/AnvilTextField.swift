import SwiftUI

public struct AnvilTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?

    public init(_ placeholder: String, text: Binding<String>, icon: String? = nil) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(AnvilColor.textTertiary)
            }
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AnvilFont.body)
                .foregroundStyle(AnvilColor.textPrimary)
        }
        .padding(.horizontal, AnvilSpacing.md)
        .padding(.vertical, AnvilSpacing.sm)
        .background(AnvilColor.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AnvilColor.borderMedium, lineWidth: 1)
        )
    }
}
