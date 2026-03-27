import SwiftUI

struct TerminalPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Terminal")
                    .font(AnvilFont.label)
                    .foregroundStyle(AnvilColor.textSecondary)
                Spacer()
            }
            .padding(.horizontal, AnvilSpacing.md)
            .padding(.vertical, AnvilSpacing.xs)

            Rectangle()
                .fill(AnvilColor.backgroundPrimary)
                .overlay(
                    Text("Terminal will be integrated here")
                        .font(AnvilFont.code)
                        .foregroundStyle(AnvilColor.textTertiary)
                )
        }
        .background(AnvilColor.backgroundSecondary)
    }
}
