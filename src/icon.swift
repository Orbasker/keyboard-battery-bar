import AppKit

let size: CGFloat = 1024
let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(size), pixelsHigh: Int(size),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0
) else { exit(1) }

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let plate = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)

NSGradient(colors: [
    NSColor(srgbRed: 0.16, green: 0.20, blue: 0.29, alpha: 1),
    NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1),
])?.draw(in: squircle, angle: -90)

squircle.lineWidth = 3
NSColor(white: 1, alpha: 0.12).setStroke()
squircle.stroke()

func drawSymbol(_ name: String, pointSize: CGFloat, color: NSColor, center: NSPoint) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return }

    let bounds = NSRect(origin: .zero, size: symbol.size)
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(in: bounds)
    color.set()
    bounds.fill(using: .sourceAtop)
    tinted.unlockFocus()

    tinted.draw(in: NSRect(
        x: center.x - symbol.size.width / 2,
        y: center.y - symbol.size.height / 2,
        width: symbol.size.width,
        height: symbol.size.height
    ))
}

drawSymbol("keyboard.fill", pointSize: 380, color: .white, center: NSPoint(x: 512, y: 610))

let trackWidth: CGFloat = 430
let trackHeight: CGFloat = 96
let track = NSRect(x: 512 - trackWidth / 2, y: 300, width: trackWidth, height: trackHeight)
let trackPath = NSBezierPath(roundedRect: track, xRadius: 34, yRadius: 34)
NSColor(white: 1, alpha: 0.18).setFill()
trackPath.fill()
trackPath.lineWidth = 8
NSColor(white: 1, alpha: 0.45).setStroke()
trackPath.stroke()

let fillInset: CGFloat = 18
let level: CGFloat = 0.63
let fillRect = NSRect(
    x: track.minX + fillInset,
    y: track.minY + fillInset,
    width: (track.width - fillInset * 2) * level,
    height: track.height - fillInset * 2
)
NSColor(srgbRed: 0.31, green: 0.85, blue: 0.47, alpha: 1).setFill()
NSBezierPath(roundedRect: fillRect, xRadius: 20, yRadius: 20).fill()

let cap = NSRect(x: track.maxX + 16, y: track.midY - 26, width: 22, height: 52)
NSColor(white: 1, alpha: 0.45).setFill()
NSBezierPath(roundedRect: cap, xRadius: 10, yRadius: 10).fill()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: outputPath))
