// Ejectus icon — Option M "Eject Card" (core; evolved from option B).
// A bold white SD card with a debossed eject glyph and gold contacts, flinging junk bits off its corner. Royal-blue tile.
// Usage: swift icon/make_icon.swift <out.png>   (renders exactly 1024×1024)
import AppKit

let S: CGFloat = 1024
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

// MARK: - Canvas (top-left origin, y down)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
ctx.setShouldAntialias(true); ctx.interpolationQuality = .high

// MARK: - Helpers
func C(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func grad(_ cols: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: space, colors: cols as CFArray, locations: locs)!
}
func fillLinear(_ p: CGPath, _ cols: [CGColor], _ a: CGPoint, _ b: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    ctx.drawLinearGradient(grad(cols, locs), start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func fillRadial(_ p: CGPath, _ cols: [CGColor], _ c: CGPoint, _ r: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    ctx.drawRadialGradient(grad(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func shadowed(_ dy: CGFloat, _ blur: CGFloat, _ col: CGColor, _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -dy), blur: blur, color: col); body(); ctx.restoreGState()
}
/// macOS-style continuous-corner tile (superellipse corners, curvature-continuous into the edges).
func squircle(_ r: CGRect, radius: CGFloat) -> CGPath {
    let L = radius * 1.30, n: CGFloat = 2.71, steps = 48
    let p = CGMutablePath()
    // corners: (cx, cy, sx, sy) corner-centre & direction toward the corner
    let corners: [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (r.maxX - L, r.minY + L, 1, -1, -.pi / 2), (r.maxX - L, r.maxY - L, 1, 1, 0),
        (r.minX + L, r.maxY - L, -1, 1, .pi / 2), (r.minX + L, r.minY + L, -1, -1, .pi)]
    var first = true
    for (cx, cy, _, _, a0) in corners {
        for i in 0...steps {
            let t = a0 + CGFloat(i) / CGFloat(steps) * (.pi / 2)
            let c = cos(t), s = sin(t)
            let x = cx + L * (c < 0 ? -1 : 1) * pow(abs(c), 2 / n)
            let y = cy + L * (s < 0 ? -1 : 1) * pow(abs(s), 2 / n)
            if first { p.move(to: CGPoint(x: x, y: y)); first = false } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
    }
    p.closeSubpath(); return p
}
/// Polygon with an individual corner radius per vertex.
func roundedPoly(_ pts: [CGPoint], _ radii: [CGFloat]) -> CGPath {
    let p = CGMutablePath(); let n = pts.count
    let mid = CGPoint(x: (pts[n - 1].x + pts[0].x) / 2, y: (pts[n - 1].y + pts[0].y) / 2)
    p.move(to: mid)
    for i in 0..<n { p.addArc(tangent1End: pts[i], tangent2End: pts[(i + 1) % n], radius: radii[i]) }
    p.closeSubpath(); return p
}
func sparkle(_ c: CGPoint, _ R: CGFloat, _ k: CGFloat = 0.16) -> CGPath {
    let p = CGMutablePath()
    let tips = [CGPoint(x: c.x, y: c.y - R), CGPoint(x: c.x + R, y: c.y), CGPoint(x: c.x, y: c.y + R), CGPoint(x: c.x - R, y: c.y)]
    p.move(to: tips[0])
    for i in 0..<4 {
        let a = tips[i], b = tips[(i + 1) % 4]
        let ctl = CGPoint(x: c.x + ((a.x - c.x) + (b.x - c.x)) * k, y: c.y + ((a.y - c.y) + (b.y - c.y)) * k)
        p.addQuadCurve(to: b, control: ctl)
    }
    p.closeSubpath(); return p
}

// MARK: - Tile
let tileRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let tile = squircle(tileRect, radius: 185)
shadowed(10, 22, C(0x000000, 0.32)) { ctx.addPath(tile); ctx.setFillColor(C(0x2340C8)); ctx.fillPath() }
fillLinear(tile, [C(0x6494FF), C(0x3557EA), C(0x2236B0)], CGPoint(x: 360, y: 100), CGPoint(x: 664, y: 924), [0, 0.5, 1])
fillRadial(tile, [C(0xFFFFFF, 0.25), C(0xFFFFFF, 0)], CGPoint(x: 380, y: 170), 520)
ctx.saveGState(); ctx.addPath(tile); ctx.clip()
ctx.addPath(tile); ctx.setLineWidth(6); ctx.replacePathWithStrokedPath(); ctx.clip()
ctx.drawLinearGradient(grad([C(0xFFFFFF, 0.55), C(0xFFFFFF, 0), C(0x000A40, 0.3)], [0, 0.5, 1]),
                       start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
ctx.restoreGState()

ctx.saveGState(); ctx.addPath(tile); ctx.clip()

// MARK: - Junk bits flung off the notch corner (drawn first so the card overlaps the launch point)
func bit(_ c: CGPoint, _ s: CGFloat, _ a: CGFloat, _ alpha: CGFloat) {
    ctx.saveGState(); ctx.translateBy(x: c.x, y: c.y); ctx.rotate(by: a)
    let p = CGPath(roundedRect: CGRect(x: -s/2, y: -s/2, width: s, height: s), cornerWidth: s * 0.24, cornerHeight: s * 0.24, transform: nil)
    shadowed(s * 0.1, s * 0.25, C(0x0A1450, 0.35)) { ctx.addPath(p); ctx.setFillColor(C(0xFFFFFF, alpha)); ctx.fillPath() }
    ctx.restoreGState()
}
let streaks = CGMutablePath()
for (a, b) in [(CGPoint(x: 708, y: 284), CGPoint(x: 772, y: 226)), (CGPoint(x: 752, y: 338), CGPoint(x: 822, y: 292))] {
    streaks.move(to: a); streaks.addLine(to: b)
}
ctx.addPath(streaks); ctx.setStrokeColor(C(0xFFFFFF, 0.45)); ctx.setLineWidth(14); ctx.setLineCap(.round); ctx.strokePath()
bit(CGPoint(x: 815, y: 186), 62, 0.5, 0.95)
bit(CGPoint(x: 866, y: 300), 38, -0.3, 0.8)
bit(CGPoint(x: 760, y: 150), 26, 0.2, 0.65)

// MARK: - Card
let x0: CGFloat = 270, x1: CGFloat = 718, y0: CGFloat = 222, y1: CGFloat = 818, notch: CGFloat = 136
let card = roundedPoly([CGPoint(x: x0, y: y0), CGPoint(x: x1 - notch, y: y0), CGPoint(x: x1, y: y0 + notch),
                        CGPoint(x: x1, y: y1), CGPoint(x: x0, y: y1)], [64, 26, 26, 64, 64])
shadowed(30, 50, C(0x0A1450, 0.5)) { ctx.addPath(card); ctx.setFillColor(C(0xFFFFFF)); ctx.fillPath() }
fillLinear(card, [C(0xFFFFFF), C(0xF2F5FF), C(0xDCE3F7)], CGPoint(x: 0, y: y0), CGPoint(x: 0, y: y1), [0, 0.6, 1])
ctx.saveGState(); ctx.addPath(card); ctx.clip()
ctx.addPath(card); ctx.setLineWidth(8); ctx.replacePathWithStrokedPath(); ctx.clip()
ctx.drawLinearGradient(grad([C(0xFFFFFF, 1), C(0xFFFFFF, 0), C(0x6A7AB0, 0.35)], [0, 0.5, 1]),
                       start: CGPoint(x: 0, y: y0), end: CGPoint(x: 0, y: y1), options: [])
ctx.restoreGState()

func deboss(_ p: CGPath, _ cols: [CGColor]) {
    fillLinear(p, cols, CGPoint(x: 0, y: 420), CGPoint(x: 0, y: 780))
    ctx.saveGState(); ctx.addPath(p); ctx.clip()
    let ring = CGMutablePath(); ring.addRect(CGRect(x: 0, y: 0, width: S, height: S)); ring.addPath(p)
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 14, color: C(0x000A40, 0.55))
    ctx.addPath(ring); ctx.setFillColor(C(0x000000)); ctx.fillPath(using: .evenOdd)
    ctx.restoreGState()
}
// gold contacts (the Latin nod)
for i in 0..<5 {
    let w: CGFloat = 40, g: CGFloat = 20
    let x = x0 + 56 + CGFloat(i) * (w + g)
    let drop: CGFloat = i == 4 ? 30 : 0
    let r = CGRect(x: x, y: y0 + 50 + drop, width: w, height: 96 - drop)
    let pad = CGPath(roundedRect: r, cornerWidth: 12, cornerHeight: 12, transform: nil)
    shadowed(-2, 3, C(0x000000, 0.3)) { ctx.addPath(pad); ctx.setFillColor(C(0xC98C2A)); ctx.fillPath() }
    fillLinear(pad, [C(0xFFF0B8), C(0xF2C766), C(0xC98C2A)], CGPoint(x: 0, y: r.minY), CGPoint(x: 0, y: r.maxY), [0, 0.35, 1])
}
// eject glyph, big and debossed
let cxE = (x0 + x1) / 2, top: CGFloat = 436, base: CGFloat = 626, half: CGFloat = 160
let tri = roundedPoly([CGPoint(x: cxE, y: top), CGPoint(x: cxE + half, y: base), CGPoint(x: cxE - half, y: base)], [28, 24, 24])
let ink = [C(0x3F66F5), C(0x1E31B0)]
deboss(tri, ink)
deboss(CGPath(roundedRect: CGRect(x: cxE - half, y: 662, width: half * 2, height: 68), cornerWidth: 24, cornerHeight: 24, transform: nil), ink)

ctx.restoreGState()

// MARK: - Save
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
