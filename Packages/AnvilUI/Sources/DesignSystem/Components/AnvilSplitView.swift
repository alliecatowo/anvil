import SwiftUI

public enum SplitOrientation: Sendable {
    case horizontal, vertical
}

public struct AnvilSplitView<Left: View, Right: View>: View {
    let left: Left
    let right: Right
    let initialRatio: CGFloat
    let minLeftWidth: CGFloat
    let minRightWidth: CGFloat
    let orientation: SplitOrientation

    public init(
        initialRatio: CGFloat = 0.5,
        minLeftWidth: CGFloat = 200,
        minRightWidth: CGFloat = 200,
        orientation: SplitOrientation = .horizontal,
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) {
        self.left = left()
        self.right = right()
        self.initialRatio = initialRatio
        self.minLeftWidth = minLeftWidth
        self.minRightWidth = minRightWidth
        self.orientation = orientation
    }

    public var body: some View {
        switch orientation {
        case .horizontal:
            HSplitView {
                left
                    .frame(minWidth: minLeftWidth)
                right
                    .frame(minWidth: minRightWidth)
            }
        case .vertical:
            VSplitView {
                left
                    .frame(minHeight: minLeftWidth)
                right
                    .frame(minHeight: minRightWidth)
            }
        }
    }
}
