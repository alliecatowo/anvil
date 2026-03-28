import SwiftUI

public struct AnvilLoadingIndicator: View {
    let size: CGFloat

    public init(size: CGFloat = 16) {
        self.size = size
    }

    public var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .controlSize(controlSize)
            .frame(width: size, height: size)
    }

    private var controlSize: ControlSize {
        if size <= 12 {
            return .mini
        } else if size <= 16 {
            return .small
        } else if size <= 24 {
            return .regular
        } else {
            return .large
        }
    }
}
