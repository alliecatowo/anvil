import SwiftUI

public enum AnvilColor {
    // Backgrounds — adaptive system colors for light/dark mode
    public static let backgroundPrimary = Color(nsColor: .windowBackgroundColor)
    public static let backgroundSecondary = Color(nsColor: .controlBackgroundColor)
    public static let backgroundTertiary = Color(nsColor: .underPageBackgroundColor)
    public static let backgroundElevated = Color(nsColor: .textBackgroundColor)
    public static let backgroundSidebar = Color(nsColor: .controlBackgroundColor)
    public static let backgroundToolbar = Color(nsColor: .windowBackgroundColor).opacity(0.82)

    // Borders — adaptive system colors
    public static let borderSubtle = Color(nsColor: .separatorColor)
    public static let borderMedium = Color(nsColor: .gridColor)
    public static let borderStrong = Color(nsColor: .tertiaryLabelColor)

    // Text — adaptive semantic colors
    public static let textPrimary = Color.primary
    public static let textSecondary = Color.secondary
    public static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // Accents
    public static let accentBlue = Color.accentColor
    public static let accentGreen = Color(nsColor: .systemGreen)
    public static let accentAmber = Color(nsColor: .systemOrange)
    public static let accentRed = Color(nsColor: .systemRed)
    public static let accentPurple = Color(nsColor: .systemPurple)
    public static let accentTeal = Color(nsColor: .systemTeal)

    // Diff
    public static let diffAddedBackground = Color(nsColor: .systemGreen).opacity(0.12)
    public static let diffRemovedBackground = Color(nsColor: .systemRed).opacity(0.12)
    public static let diffAddedText = Color(nsColor: .systemGreen)
    public static let diffRemovedText = Color(nsColor: .systemRed)

    // Selection
    public static let selectionBackground = Color.accentColor.opacity(0.15)
    public static let selectionBorder = Color.accentColor.opacity(0.6)
}

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}
