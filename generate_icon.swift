#!/usr/bin/env swift

import AppKit
import Foundation

func generateIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(size)

    // Background: rounded rectangle with gradient
    let cornerRadius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Dark gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 0.10, green: 0.10, blue: 0.14, alpha: 1.0),
        CGColor(red: 0.16, green: 0.16, blue: 0.22, alpha: 1.0),
    ]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    ctx.restoreGState()

    // Draw the anvil symbol using the "anvil" shape: a stylized "A" with a hammer accent
    // We'll use SF Symbol "hammer.fill" concept but draw a simplified anvil shape

    let cx = s / 2
    let cy = s / 2

    // Anvil body - flat top surface
    ctx.saveGState()
    let anvilColor = CGColor(red: 0.55, green: 0.62, blue: 0.78, alpha: 1.0)
    let anvilHighlight = CGColor(red: 0.70, green: 0.76, blue: 0.90, alpha: 1.0)

    // Main anvil body
    let anvilPath = CGMutablePath()
    let aw = s * 0.52  // anvil width
    let ah = s * 0.32  // anvil height
    let ax = cx - aw/2
    let ay = cy - ah/2 - s * 0.02

    // Anvil shape: flat top, tapered base with horn on left
    anvilPath.move(to: CGPoint(x: ax - s*0.06, y: ay + ah * 0.35))  // horn tip (left)
    anvilPath.addLine(to: CGPoint(x: ax + s*0.02, y: ay + ah * 0.30))  // horn base
    anvilPath.addLine(to: CGPoint(x: ax + s*0.02, y: ay))  // top left
    anvilPath.addLine(to: CGPoint(x: ax + aw, y: ay))  // top right
    anvilPath.addLine(to: CGPoint(x: ax + aw, y: ay + ah * 0.30))  // right step
    anvilPath.addLine(to: CGPoint(x: ax + aw - s*0.06, y: ay + ah * 0.30))  // right inset
    anvilPath.addLine(to: CGPoint(x: ax + aw - s*0.10, y: ay + ah))  // bottom right
    anvilPath.addLine(to: CGPoint(x: ax + s*0.10, y: ay + ah))  // bottom left
    anvilPath.addLine(to: CGPoint(x: ax + s*0.06, y: ay + ah * 0.30))  // left inset
    anvilPath.closeSubpath()

    // Anvil gradient
    ctx.addPath(anvilPath)
    ctx.clip()
    let anvilGrad = CGGradient(colorsSpace: colorSpace, colors: [anvilHighlight, anvilColor] as CFArray, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(anvilGrad, start: CGPoint(x: cx, y: ay), end: CGPoint(x: cx, y: ay + ah), options: [])
    ctx.restoreGState()

    // Anvil top surface highlight line
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.88, blue: 0.95, alpha: 0.6))
    ctx.setLineWidth(s * 0.012)
    ctx.move(to: CGPoint(x: ax + s*0.04, y: ay + s*0.008))
    ctx.addLine(to: CGPoint(x: ax + aw - s*0.02, y: ay + s*0.008))
    ctx.strokePath()
    ctx.restoreGState()

    // Accent glow: blue accent at the top
    ctx.saveGState()
    let glowColor = CGColor(red: 0.30, green: 0.55, blue: 1.0, alpha: 0.25)
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: [glowColor, CGColor(red: 0.3, green: 0.55, blue: 1.0, alpha: 0.0)] as CFArray, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glowGrad, startCenter: CGPoint(x: cx, y: ay - s*0.02), startRadius: 0, endCenter: CGPoint(x: cx, y: ay - s*0.02), endRadius: s * 0.3, options: [])
    ctx.restoreGState()

    // Subtle "A" letter in the center of the anvil
    let font = CTFontCreateWithName("SF Pro Display" as CFString, s * 0.18, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.98, alpha: 0.9)
    ]
    let attrStr = NSAttributedString(string: "A", attributes: attributes)
    let line = CTLineCreateWithAttributedString(attrStr)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    ctx.saveGState()
    ctx.textPosition = CGPoint(x: cx - bounds.width/2 - bounds.origin.x, y: cy - bounds.height/2 - bounds.origin.y - s*0.02)
    CTLineDraw(line, ctx)
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func saveIcon(_ image: NSImage, size: Int, path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG for size \(size)")
        return
    }
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Generated \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

let basePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

for size in [128, 256, 512, 1024] {
    let image = generateIcon(size: size)
    saveIcon(image, size: size, path: "\(basePath)/icon_\(size)x\(size).png")
}
