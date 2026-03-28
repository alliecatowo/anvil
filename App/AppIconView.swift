import SwiftUI
import AppKit

/// The Anvil app icon rendered programmatically.
/// Use `AppIconView.generateIconFiles()` to write PNGs to the asset catalog.
struct AppIconView: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Background rounded rect with dark gradient
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.16, blue: 0.22),
                            Color(red: 0.10, green: 0.10, blue: 0.14)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // Blue accent glow at top
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.30, green: 0.55, blue: 1.0).opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.6, height: size * 0.4)
                .offset(y: -size * 0.12)

            // Anvil shape
            AnvilShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.70, green: 0.76, blue: 0.90),
                            Color(red: 0.50, green: 0.56, blue: 0.72)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.55, height: size * 0.35)

            // Letter "A" centered on anvil
            Text("A")
                .font(.system(size: size * 0.18, weight: .bold, design: .default))
                .foregroundStyle(
                    Color(red: 0.92, green: 0.94, blue: 0.98).opacity(0.9)
                )
                .offset(y: -size * 0.01)
        }
        .frame(width: size, height: size)
    }

    /// Generate icon PNG files into the AppIcon.appiconset directory.
    @MainActor
    static func generateIconFiles() {
        let sizes = [1024]
        let basePath = Bundle.main.resourceURL?
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset")

        guard let outputDir = basePath else {
            print("Could not determine asset catalog path")
            return
        }

        for size in sizes {
            let view = AppIconView(size: CGFloat(size))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1.0

            if let cgImage = renderer.cgImage {
                let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
                if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                    let url = outputDir.appendingPathComponent("icon_\(size)x\(size).png")
                    try? pngData.write(to: url)
                    print("Generated icon at \(url.path)")
                }
            }
        }
    }
}

/// A custom anvil shape for the app icon.
struct AnvilShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let x = rect.minX
        let y = rect.minY

        // Horn (left extension)
        path.move(to: CGPoint(x: x - w * 0.08, y: y + h * 0.38))
        path.addLine(to: CGPoint(x: x + w * 0.05, y: y + h * 0.30))

        // Top surface
        path.addLine(to: CGPoint(x: x + w * 0.05, y: y))
        path.addLine(to: CGPoint(x: x + w, y: y))

        // Right side step down
        path.addLine(to: CGPoint(x: x + w, y: y + h * 0.30))
        path.addLine(to: CGPoint(x: x + w - w * 0.08, y: y + h * 0.30))

        // Bottom right (tapered)
        path.addLine(to: CGPoint(x: x + w - w * 0.15, y: y + h))

        // Base
        path.addLine(to: CGPoint(x: x + w * 0.15, y: y + h))

        // Bottom left (tapered)
        path.addLine(to: CGPoint(x: x + w * 0.08, y: y + h * 0.30))

        path.closeSubpath()
        return path
    }
}
