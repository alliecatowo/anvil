import SwiftUI

public struct AnvilCard<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GroupBox {
            content
        }
    }
}
