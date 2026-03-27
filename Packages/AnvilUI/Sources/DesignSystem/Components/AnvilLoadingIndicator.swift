import SwiftUI

public struct AnvilLoadingIndicator: View {
    let size: CGFloat
    @State private var isAnimating = false

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(AnvilColor.accentPurple, lineWidth: 2)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}
