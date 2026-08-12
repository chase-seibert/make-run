import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("Usage: swift GenerateIcon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
let background = NSGradient(
    starting: NSColor(red: 0.10, green: 0.20, blue: 0.30, alpha: 1),
    ending: NSColor(red: 0.08, green: 0.48, blue: 0.42, alpha: 1)
)!
background.draw(in: bounds, angle: -48)

let panelRect = NSRect(x: 126, y: 180, width: 772, height: 664)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 62, yRadius: 62)
NSColor(white: 0.04, alpha: 0.82).setFill()
panel.fill()

let topLine = NSBezierPath()
topLine.move(to: NSPoint(x: 126, y: 710))
topLine.line(to: NSPoint(x: 898, y: 710))
topLine.lineWidth = 18
NSColor.white.withAlphaComponent(0.20).setStroke()
topLine.stroke()

for (index, color) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
    color.setFill()
    NSBezierPath(ovalIn: NSRect(x: 190 + CGFloat(index) * 76, y: 758, width: 38, height: 38)).fill()
}

let cursor = NSBezierPath()
cursor.move(to: NSPoint(x: 260, y: 580))
cursor.line(to: NSPoint(x: 420, y: 470))
cursor.line(to: NSPoint(x: 260, y: 360))
cursor.lineWidth = 58
cursor.lineCapStyle = .round
cursor.lineJoinStyle = .round
NSColor.white.setStroke()
cursor.stroke()

let underscore = NSBezierPath()
underscore.move(to: NSPoint(x: 482, y: 350))
underscore.line(to: NSPoint(x: 716, y: 350))
underscore.lineWidth = 58
underscore.lineCapStyle = .round
NSColor.white.setStroke()
underscore.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let representation = NSBitmapImageRep(data: tiff),
      let png = representation.representation(using: .png, properties: [:]) else {
    fputs("Could not render icon\n", stderr)
    exit(1)
}
try png.write(to: URL(fileURLWithPath: arguments[1]), options: .atomic)
