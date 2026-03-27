import SwiftUI

public struct AnvilBadge: View {
    let text: String
    let color: Color

    public init(text: String, color: Color = AnvilColor.accentBlue) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
