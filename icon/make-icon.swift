// Draws the EyeRest app icon and writes icon/AppIcon.icns. Run: swift icon/make-icon.swift
import AppKit

let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

// Tile: the macOS icon grid's 824pt rounded square, with a soft drop shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x000000, 0.35)
shadow.shadowBlurRadius = 28
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.set()
color(0x1C4A7E).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(colors: [color(0x5EE0C6), color(0x2A9FB8), color(0x1D4C86)], atLocations: [0, 0.5, 1],
           colorSpace: .sRGB)!.draw(in: tilePath, angle: -90)

// A far-away horizon: two soft hills along the bottom of the tile.
NSGraphicsContext.saveGraphicsState()
tilePath.addClip()
let hills = NSBezierPath()
hills.move(to: NSPoint(x: 100, y: 300))
hills.curve(to: NSPoint(x: 560, y: 330), controlPoint1: NSPoint(x: 260, y: 380), controlPoint2: NSPoint(x: 420, y: 380))
hills.curve(to: NSPoint(x: 924, y: 290), controlPoint1: NSPoint(x: 700, y: 280), controlPoint2: NSPoint(x: 820, y: 360))
hills.line(to: NSPoint(x: 924, y: 100))
hills.line(to: NSPoint(x: 100, y: 100))
hills.close()
color(0x123A66, 0.55).setFill()
hills.fill()
NSGraphicsContext.restoreGraphicsState()

// The eye: an almond outline with an iris, pupil and highlight.
let c = NSPoint(x: 512, y: 560)
let eye = NSBezierPath()
eye.move(to: NSPoint(x: c.x - 300, y: c.y))
eye.curve(to: NSPoint(x: c.x + 300, y: c.y), controlPoint1: NSPoint(x: c.x - 150, y: c.y + 250), controlPoint2: NSPoint(x: c.x + 150, y: c.y + 250))
eye.curve(to: NSPoint(x: c.x - 300, y: c.y), controlPoint1: NSPoint(x: c.x + 150, y: c.y - 250), controlPoint2: NSPoint(x: c.x - 150, y: c.y - 250))
eye.close()
NSGraphicsContext.saveGraphicsState()
let eyeShadow = NSShadow()
eyeShadow.shadowColor = color(0x0B2340, 0.35)
eyeShadow.shadowBlurRadius = 24
eyeShadow.shadowOffset = NSSize(width: 0, height: -8)
eyeShadow.set()
color(0xFFFFFF).setFill()
eye.fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
eye.addClip()
let iris = NSBezierPath(ovalIn: NSRect(x: c.x - 125, y: c.y - 125, width: 250, height: 250))
NSGradient(starting: color(0x38C9B0), ending: color(0x1B6E9E))!.draw(in: iris, angle: -90)
color(0x0E2A4A).setFill()
NSBezierPath(ovalIn: NSRect(x: c.x - 58, y: c.y - 58, width: 116, height: 116)).fill()
color(0xFFFFFF, 0.9).setFill()
NSBezierPath(ovalIn: NSRect(x: c.x + 18, y: c.y + 30, width: 44, height: 44)).fill()
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.current = nil

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon")
let iconset = dir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: dir.appendingPathComponent("AppIcon.png"))

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = points * scale
        let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        NSGraphicsContext.current!.imageInterpolation = .high
        rep.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.current = nil
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try! out.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", dir.appendingPathComponent("AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
print("wrote \(dir.path)/AppIcon.icns")
