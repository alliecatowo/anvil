import SwiftUI

public enum AnvilColor {
    // Backgrounds
    public static let backgroundPrimary = Color(hex: 0x0D0D0D)
    public static let backgroundSecondary = Color(hex: 0x161616)
    public static let backgroundTertiary = Color(hex: 0x1E1E1E)
    public static let backgroundElevated = Color(hex: 0x252525)

    // Borders
    public static let borderSubtle = Color(hex: 0x2A2A2A)
    public static let borderMedium = Color(hex: 0x3A3A3A)
    public static let borderStrong = Color(hex: 0x505050)

    // Text
    public static let textPrimary = Color(hex: 0xEDEDED)
    public static let textSecondary = Color(hex: 0x999999)
    public static let textTertiary = Color(hex: 0x666666)

    // Accents
    public static let accentBlue = Color(hex: 0x3B82F6)
    public static let accentGreen = Color(hex: 0x22C55E)
    public static let accentAmber = Color(hex: 0xF59E0B)
    public static let accentRed = Color(hex: 0xEF4444)
    public static let accentPurple = Color(hex: 0xA855F7)
    public static let accentTeal = Color(hex: 0x14B8A6)

    // Diff
    public static let diffAddedBackground = Color(hex: 0x22C55E).opacity(0.1)
    public static let diffRemovedBackground = Color(hex: 0xEF4444).opacity(0.1)
    public static let diffAddedText = Color(hex: 0x4ADE80)
    public static let diffRemovedText = Color(hex: 0xF87171)

    // Selection
    public static let selectionBackground = Color(hex: 0x3B82F6).opacity(0.2)
    public static let selectionBorder = Color(hex: 0x3B82F6).opacity(0.6)
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
