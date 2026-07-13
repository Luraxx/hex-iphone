// Generates the app icon (1024x1024) without Xcode: `swift scripts/make_icon.swift`
import AppKit

let size = CGSize(width: 1024, height: 1024)
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: dark gradient
let bg = NSGradient(
    starting: NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1),
    ending: NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.07, alpha: 1)
)!
bg.draw(in: NSRect(origin: .zero, size: size), angle: -90)

// Hexagon (pointy top), like Hex's ⬡
func hexPath(center: CGPoint, radius: CGFloat) -> NSBezierPath {
    let path = NSBezierPath()
    for i in 0 ..< 6 {
        let angle = CGFloat.pi / 2 + CGFloat(i) * CGFloat.pi / 3
        let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        if i == 0 { path.move(to: point) } else { path.line(to: point) }
    }
    path.close()
    return path
}

let center = CGPoint(x: 512, y: 512)
let outer = hexPath(center: center, radius: 340)
outer.lineWidth = 58
outer.lineJoinStyle = .round
NSColor.white.setStroke()
outer.stroke()

// Inner dot (microphone hint)
let dotRadius: CGFloat = 84
let dot = NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
NSColor(calibratedRed: 0.204, green: 0.471, blue: 0.965, alpha: 1).setFill()
dot.fill()

NSGraphicsContext.restoreGraphicsState()

let outURL = URL(fileURLWithPath: "Hex/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try! rep.representation(using: .png, properties: [:])!.write(to: outURL)
print("Icon written: \(outURL.path)")
