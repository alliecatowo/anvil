import SwiftUI

/// A lightweight wrapper that adds hover highlight and press-scale micro-interactions
/// to any row content. Use this for sidebar rows that are not already using
/// `AnvilSidebarRowButton` or `AnvilListItem`.
struct HoverableRow<Content: View>: View {
    var isSelected: Bool = false
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false
    @GestureState private var isPressed = false

    var body: some View {
        content()
            .background(
                isSelected
                    ? AnvilColor.selectionBackground
                    : (isHovered ? Color.primary.opacity(0.06) : .clear)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressed) { _, pressed, _ in pressed = true }
            )
            .onHover { isHovered = $0 }
    }
}
