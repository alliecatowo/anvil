import SwiftUI

public enum AnvilAnimation {
    public static let standard = Animation.easeOut(duration: 0.15)
    public static let sidebarCollapse = Animation.spring(response: 0.5, dampingFraction: 0.85)
    public static let commandPaletteAppear = Animation.easeOut(duration: 0.1)
    public static let listItemChange = Animation.easeOut(duration: 0.15)
    public static let modeSwitch = Animation.easeInOut(duration: 0.12)
}
