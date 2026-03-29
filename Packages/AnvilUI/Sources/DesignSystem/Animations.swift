import SwiftUI

public enum AnvilAnimation {
    /// Primary state transition — macOS Tahoe spring
    public static let standard = Animation.spring(response: 0.3, dampingFraction: 0.8)
    public static let sidebarCollapse = Animation.spring(response: 0.4, dampingFraction: 0.85)
    public static let commandPaletteAppear = Animation.spring(response: 0.25, dampingFraction: 0.9)
    public static let listItemChange = Animation.spring(response: 0.3, dampingFraction: 0.8)
    public static let modeSwitch = Animation.spring(response: 0.25, dampingFraction: 0.85)
}
