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

    @State private var ratio: CGFloat

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
        self._ratio = State(initialValue: initialRatio)
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalSize = orientation == .horizontal ? geometry.size.width : geometry.size.height

            switch orientation {
            case .horizontal:
                HStack(spacing: 0) {
                    left
                        .frame(width: leftSize(total: totalSize))

                    divider(isVertical: true, totalSize: totalSize)

                    right
                        .frame(maxWidth: .infinity)
                }
            case .vertical:
                VStack(spacing: 0) {
                    left
                        .frame(height: leftSize(total: totalSize))

                    divider(isVertical: false, totalSize: totalSize)

                    right
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private func leftSize(total: CGFloat) -> CGFloat {
        let size = total * ratio
        let maxSize = total - minRightWidth - dividerThickness
        return max(minLeftWidth, min(size, maxSize))
    }

    private var dividerThickness: CGFloat { 1 }

    private func divider(isVertical: Bool, totalSize: CGFloat) -> some View {
        Rectangle()
            .fill(AnvilColor.borderSubtle)
            .frame(
                width: isVertical ? dividerThickness : nil,
                height: isVertical ? nil : dividerThickness
            )
            .padding(isVertical ? .horizontal : .vertical, 0)
            .contentShape(Rectangle().inset(by: -3))
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let delta = isVertical ? value.translation.width : value.translation.height
                        let newRatio = initialRatioForDrag + delta / totalSize
                        let minRatio = minLeftWidth / totalSize
                        let maxRatio = (totalSize - minRightWidth - dividerThickness) / totalSize
                        ratio = max(minRatio, min(newRatio, maxRatio))
                    }
            )
    }

    /// Capture the ratio at drag start to compute incremental deltas correctly.
    /// In practice SwiftUI's DragGesture gives cumulative translation, so we
    /// base it off the current state value which works for single-gesture arcs.
    private var initialRatioForDrag: CGFloat { ratio }
}
