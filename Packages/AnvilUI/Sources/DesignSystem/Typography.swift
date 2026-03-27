import SwiftUI

public enum AnvilFont {
    public static let body = Font.system(size: 13, weight: .regular)
    public static let label = Font.system(size: 11, weight: .medium).monospacedDigit()
    public static let sidebarItem = Font.system(size: 13, weight: .regular)
    public static let sidebarHeader = Font.system(size: 14, weight: .medium)
    public static let heading = Font.system(size: 20, weight: .semibold, design: .default)
    public static let subheading = Font.system(size: 15, weight: .medium, design: .default)
    public static let code = Font.system(size: 12, weight: .regular, design: .monospaced)
    public static let commandPaletteInput = Font.system(size: 15, weight: .regular)
    public static let commandPaletteResult = Font.system(size: 13, weight: .regular)
    public static let statusBar = Font.system(size: 11, weight: .regular, design: .monospaced)
}
