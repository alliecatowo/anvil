import SwiftUI

/// A lightweight wrapper that adds hover highlight to any row content.
/// Use this for sidebar rows that are not already using
/// `AnvilSidebarRowButton` or `AnvilListItem`.
struct HoverableRow<Content: View>: View {
    var isSelected: Bool = false
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false

    var body: some View {
        content()
            .background(
                isSelected
                    ? AnvilColor.selectionBackground
                    : (isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }
}
