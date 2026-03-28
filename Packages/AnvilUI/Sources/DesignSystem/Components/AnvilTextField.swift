import SwiftUI

/// Native-style text field that wraps TextField with consistent Anvil styling.
/// Use this instead of TextField + .textFieldStyle(.plain) + manual border.
public struct AnvilTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String?
    let axis: Axis
    var onSubmit: (() -> Void)?

    public init(
        _ placeholder: String,
        text: Binding<String>,
        icon: String? = nil,
        axis: Axis = .horizontal,
        onSubmit: (() -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.icon = icon
        self.axis = axis
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: AnvilSpacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            if axis == .vertical {
                TextField(placeholder, text: $text, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onSubmit?() }
            } else {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { onSubmit?() }
            }
        }
    }
}
