// Draws the DriveSweep app icon: run `swift icon/make_icon.swift <out.png>` (1024×1024).
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// macOS tile: rounded square with a little margin, deep blue → teal gradient.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill(); tilePath.fill()
ctx.restoreGState()
tilePath.addClip()
NSGradient(colors: [NSColor(red: 0.10, green: 0.23, blue: 0.55, alpha: 1),
                    NSColor(red: 0.07, green: 0.62, blue: 0.75, alpha: 1)])!
    .draw(in: tile, angle: 60)

// SD card: rounded rect with the top-right corner cut off, slightly tilted.
ctx.saveGState()
ctx.translateBy(x: 512, y: 480)
ctx.rotate(by: -0.12)
let w: CGFloat = 380, h: CGFloat = 480, cut: CGFloat = 95, r: CGFloat = 36
let card = NSBezierPath()
card.move(to: NSPoint(x: -w/2 + r, y: -h/2))
card.line(to: NSPoint(x: w/2 - r, y: -h/2))
card.appendArc(withCenter: NSPoint(x: w/2 - r, y: -h/2 + r), radius: r, startAngle: 270, endAngle: 360)
card.line(to: NSPoint(x: w/2, y: h/2 - cut))
card.line(to: NSPoint(x: w/2 - cut, y: h/2))
card.line(to: NSPoint(x: -w/2 + r, y: h/2))
card.appendArc(withCenter: NSPoint(x: -w/2 + r, y: h/2 - r), radius: r, startAngle: 90, endAngle: 180)
card.line(to: NSPoint(x: -w/2, y: -h/2 + r))
card.appendArc(withCenter: NSPoint(x: -w/2 + r, y: -h/2 + r), radius: r, startAngle: 180, endAngle: 270)
card.close()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
NSColor(white: 0.97, alpha: 1).setFill(); card.fill()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Gold contacts along the top.
NSColor(red: 0.95, green: 0.74, blue: 0.25, alpha: 1).setFill()
for i in 0..<5 {
    let x = -w/2 + 40 + CGFloat(i) * 56
    NSBezierPath(roundedRect: NSRect(x: x, y: h/2 - 150, width: 36, height: 110), xRadius: 8, yRadius: 8).fill()
}
// Label area.
NSColor(red: 0.10, green: 0.23, blue: 0.55, alpha: 0.12).setFill()
NSBezierPath(roundedRect: NSRect(x: -w/2 + 40, y: -h/2 + 40, width: w - 80, height: 200), xRadius: 20, yRadius: 20).fill()
ctx.restoreGState()

// Sparkles = "clean".
func sparkle(_ c: NSPoint, _ s: CGFloat) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: c.x, y: c.y + s))
    p.curve(to: NSPoint(x: c.x + s, y: c.y), controlPoint1: NSPoint(x: c.x + s*0.12, y: c.y + s*0.12), controlPoint2: NSPoint(x: c.x + s*0.12, y: c.y + s*0.12))
    p.curve(to: NSPoint(x: c.x, y: c.y - s), controlPoint1: NSPoint(x: c.x + s*0.12, y: c.y - s*0.12), controlPoint2: NSPoint(x: c.x + s*0.12, y: c.y - s*0.12))
    p.curve(to: NSPoint(x: c.x - s, y: c.y), controlPoint1: NSPoint(x: c.x - s*0.12, y: c.y - s*0.12), controlPoint2: NSPoint(x: c.x - s*0.12, y: c.y - s*0.12))
    p.curve(to: NSPoint(x: c.x, y: c.y + s), controlPoint1: NSPoint(x: c.x - s*0.12, y: c.y + s*0.12), controlPoint2: NSPoint(x: c.x - s*0.12, y: c.y + s*0.12))
    NSColor.white.setFill(); p.fill()
}
sparkle(NSPoint(x: 760, y: 760), 95)
sparkle(NSPoint(x: 820, y: 560), 45)
sparkle(NSPoint(x: 250, y: 290), 55)

image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("Wrote \(out)")
