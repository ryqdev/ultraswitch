#!/usr/bin/env swift
import AppKit

// Generates the UltraSwitch app icon: a macOS squircle with a stack of
// overlapping window cards (traffic-light dots) on a blue→indigo gradient.
// Renders every size required by an .iconset and lets iconutil build the .icns.

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}

/// A continuous-corner-ish rounded rect (approximated with circular corners).
func squircle(in rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

/// Rounded window card with a title bar and three traffic-light dots.
func drawWindowCard(_ rect: NSRect, fill: NSColor, barColor: NSColor, dots: Bool, s: CGFloat) {
    let radius = s * 0.045
    let path = squircle(in: rect, radius: radius)

    // soft drop shadow
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = s * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.set()
    fill.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // title bar
    let barHeight = rect.height * 0.22
    let barRect = NSRect(x: rect.minX, y: rect.maxY - barHeight, width: rect.width, height: barHeight)
    NSGraphicsContext.saveGraphicsState()
    squircle(in: rect, radius: radius).addClip()
    barColor.setFill()
    NSBezierPath(rect: barRect).fill()
    NSGraphicsContext.restoreGraphicsState()

    if dots {
        let dotR = barHeight * 0.20
        let cy = barRect.midY
        let colors = [color(255, 95, 86), color(255, 189, 46), color(39, 201, 63)]
        for (i, c) in colors.enumerated() {
            let cx = rect.minX + barHeight * 0.55 + CGFloat(i) * dotR * 3.1
            c.setFill()
            NSBezierPath(ovalIn: NSRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)).fill()
        }
        // content lines
        color(60, 70, 90, 0.16).setFill()
        let lineH = rect.height * 0.05
        let pad = rect.width * 0.12
        var ly = barRect.minY - rect.height * 0.16
        for w in [0.66, 0.46, 0.56] {
            let lr = NSRect(x: rect.minX + pad, y: ly, width: rect.width * CGFloat(w), height: lineH)
            NSBezierPath(roundedRect: lr, xRadius: lineH/2, yRadius: lineH/2).fill()
            ly -= rect.height * 0.135
        }
    }
}

func makeIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    let ctx = NSGraphicsContext.current!
    ctx.imageInterpolation = .high

    // Icon art is inset from the canvas, per macOS icon grid.
    let inset = size * 0.10
    let rect = NSRect(x: inset, y: inset, width: size - inset*2, height: size - inset*2)
    let s = rect.width
    let cornerRadius = s * 0.2237

    // background gradient (blue → indigo)
    let bg = squircle(in: rect, radius: cornerRadius)
    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    let grad = NSGradient(colors: [color(79, 156, 255), color(91, 52, 212)],
                          atLocations: [0, 1],
                          colorSpace: .sRGB)!
    grad.draw(in: rect, angle: -65)
    // subtle top sheen
    let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.18), NSColor.white.withAlphaComponent(0)],
                           atLocations: [0, 1], colorSpace: .sRGB)!
    sheen.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // back card (upper-right, translucent)
    let cardW = s * 0.50
    let cardH = s * 0.40
    let back = NSRect(x: rect.minX + s * 0.34,
                      y: rect.minY + s * 0.40,
                      width: cardW, height: cardH)
    drawWindowCard(back, fill: NSColor.white.withAlphaComponent(0.55),
                   barColor: NSColor.white.withAlphaComponent(0.30), dots: false, s: s)

    // front card (lower-left, opaque, focused)
    let front = NSRect(x: rect.minX + s * 0.16,
                       y: rect.minY + s * 0.18,
                       width: cardW, height: cardH)
    drawWindowCard(front, fill: .white,
                   barColor: color(238, 242, 248), dots: true, s: s)

    // thin border on the squircle for crisp edge
    NSColor.white.withAlphaComponent(0.10).setStroke()
    bg.lineWidth = max(1, s * 0.004)
    bg.stroke()

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, pixels: Int, to path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: path))
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let sizes: [(name: String, px: Int)] = [
    ("icon_16x16",      16),  ("icon_16x16@2x",   32),
    ("icon_32x32",      32),  ("icon_32x32@2x",   64),
    ("icon_128x128",   128),  ("icon_128x128@2x",256),
    ("icon_256x256",   256),  ("icon_256x256@2x",512),
    ("icon_512x512",   512),  ("icon_512x512@2x",1024),
]
for entry in sizes {
    let img = makeIcon(size: CGFloat(entry.px))
    writePNG(img, pixels: entry.px, to: "\(outDir)/\(entry.name).png")
}
// also a standalone 1024 preview
writePNG(makeIcon(size: 1024), pixels: 1024, to: "\(outDir)/preview-1024.png")
print("Generated icon assets in \(outDir)")
