// Renders the README motion graphic.
// swift icon.swift build/icon.png && swift docs/demo.swift build/icon.png docs/demo.gif
import AppKit
import ImageIO
import UniformTypeIdentifiers

let W: CGFloat = 900, H: CGFloat = 500, fps = 15.0, duration = 12.0
let icon = NSImage(contentsOfFile: CommandLine.arguments[1])!
let out = URL(fileURLWithPath: CommandLine.arguments[2])

// MARK: Layout (y grows down)

let statusIcon = NSPoint(x: 470, y: 12)
let mainMenu = NSRect(x: 458, y: 26, width: 184, height: 151)
let mainItems = ["All lights", "Bedroom", "Living Room", "-", "Rediscover", "Start at Login", "Quit Lumo"]
let sub = NSRect(x: 646, y: 26, width: 230, height: 427)
let trackX: ClosedRange<CGFloat> = 664...856
let brightnessY: CGFloat = 114, tempY: CGFloat = 158
let wheelRect = NSRect(x: 691, y: 271, width: 140, height: 140)
let scenesRow = NSRect(x: 646, y: 426, width: 230, height: 22)
let scenesMenu = NSRect(x: 472, y: 304, width: 170, height: 186)
let sceneNames = ["Ocean", "Sunset", "Fireplace", "Cozy", "Focus", "Relax", "Night Light", "Christmas"]
let bulbCentre = NSPoint(x: 225, y: 250)

let swatches: [NSColor] = [
    .init(red: 1, green: 0, blue: 0, alpha: 1), .init(red: 1, green: 0.4, blue: 0, alpha: 1),
    .init(red: 1, green: 0.85, blue: 0, alpha: 1), .init(red: 0.5, green: 1, blue: 0, alpha: 1),
    .init(red: 0, green: 1, blue: 0, alpha: 1), .init(red: 0, green: 1, blue: 0.8, alpha: 1),
    .init(red: 0, green: 0.6, blue: 1, alpha: 1), .init(red: 0, green: 0, blue: 1, alpha: 1),
    .init(red: 0.45, green: 0, blue: 1, alpha: 1), .init(red: 0.8, green: 0, blue: 1, alpha: 1),
    .init(red: 1, green: 0, blue: 0.8, alpha: 1), .init(red: 1, green: 0.3, blue: 0.5, alpha: 1),
]
func swatchRect(_ i: Int) -> NSRect { NSRect(x: 664 + CGFloat(i % 6) * 32, y: 205 + CGFloat(i / 6) * 32, width: 24, height: 24) }
func swatchCentre(_ i: Int) -> NSPoint { let r = swatchRect(i); return NSPoint(x: r.midX, y: r.midY) }
func sliderX(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { trackX.lowerBound + (v - lo) / (hi - lo) * (trackX.upperBound - trackX.lowerBound) }
func wheelPoint(_ angle: CGFloat, _ sat: CGFloat) -> NSPoint {
    // The wheel is drawn with y up, so flip the angle for y-down layout.
    NSPoint(x: wheelRect.midX + cos(angle) * sat * 70, y: wheelRect.midY - sin(angle) * sat * 70)
}
func sceneRow(_ i: Int) -> NSRect { NSRect(x: scenesMenu.minX, y: scenesMenu.minY + 5 + CGFloat(i) * 22, width: scenesMenu.width, height: 22) }

// MARK: Timeline

let warmWhite = NSColor(red: 1, green: 0.8, blue: 0.55, alpha: 1)
let wheelStart: CGFloat = 0.3, wheelSat: CGFloat = 0.8
let clicks: [(t: Double, p: NSPoint)] = [
    (2.2, statusIcon),
    (3.4, swatchCentre(0)), (3.9, swatchCentre(4)), (4.4, swatchCentre(7)), (4.9, swatchCentre(9)),
    (5.3, wheelPoint(wheelStart, wheelSat)),
    (7.0, NSPoint(x: sliderX(100, 10, 100), y: brightnessY)),
    (8.8, NSPoint(x: sceneRow(2).midX, y: sceneRow(2).midY)),
]
let path: [(t: Double, p: NSPoint)] = [
    (0, NSPoint(x: 330, y: 330)), (1.6, NSPoint(x: 330, y: 330)), (2.2, statusIcon),
    (2.6, NSPoint(x: 540, y: 42)), (3.0, NSPoint(x: 600, y: 42)),
] + clicks[1...4].map { ($0.t, $0.p) } + [(5.3, clicks[5].p)]

func smooth(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }
func lerp(_ a: CGFloat, _ b: CGFloat, _ k: Double) -> CGFloat { a + (b - a) * CGFloat(k) }
func lerp(_ a: NSPoint, _ b: NSPoint, _ k: Double) -> NSPoint { NSPoint(x: lerp(a.x, b.x, k), y: lerp(a.y, b.y, k)) }
func follow(_ keys: [(t: Double, p: NSPoint)], _ t: Double) -> NSPoint {
    guard let j = keys.firstIndex(where: { $0.t > t }) else { return keys.last!.p }
    if j == 0 { return keys[0].p }
    let a = keys[j - 1], b = keys[j]
    return lerp(a.p, b.p, smooth((t - a.t) / (b.t - a.t)))
}

struct State {
    var cursor = NSPoint.zero, card: CGFloat = 0
    var menu = false, submenu = false, scenes = false, fireplaceHover = false
    var colour = warmWhite, brightness: CGFloat = 0.9, label = "Warm white"
    var wheelKnob: NSPoint?
}

func brightnessAt(_ t: Double) -> CGFloat {
    if t < 7.0 { return 100 }
    if t < 7.5 { return lerp(100, 30, smooth((t - 7.0) / 0.5)) }
    if t < 7.9 { return lerp(30, 85, smooth((t - 7.5) / 0.4)) }
    return 85
}

func state(_ t: Double) -> State {
    var s = State()
    s.card = t < 1.3 ? 1 : t < 1.8 ? CGFloat(1 - smooth((t - 1.3) / 0.5)) : t < 10.6 ? 0 : CGFloat(smooth((t - 10.6) / 0.5))
    s.menu = t >= 2.3 && t < 9.9
    s.submenu = t >= 2.8 && t < 9.9
    s.scenes = t >= 8.3 && t < 9.9
    s.fireplaceHover = t >= 8.6 && t < 9.9

    // Cursor.
    let wheelAngle = wheelStart + CGFloat(smooth((t - 5.3) / 1.4)) * 2 * .pi
    if t < 5.3 { s.cursor = follow(path, t) }
    else if t < 6.7 { s.cursor = wheelPoint(wheelAngle, wheelSat) }
    else if t < 7.0 { s.cursor = lerp(wheelPoint(wheelStart, wheelSat), clicks[6].p, smooth((t - 6.7) / 0.3)) }
    else if t < 7.9 { s.cursor = NSPoint(x: sliderX(brightnessAt(t), 10, 100), y: brightnessY) }
    else if t < 8.3 { s.cursor = lerp(NSPoint(x: sliderX(85, 10, 100), y: brightnessY), NSPoint(x: scenesRow.midX, y: scenesRow.midY), smooth((t - 7.9) / 0.4)) }
    else if t < 8.7 { s.cursor = lerp(NSPoint(x: scenesRow.midX, y: scenesRow.midY), clicks[7].p, smooth((t - 8.3) / 0.4)) }
    else if t < 9.9 { s.cursor = clicks[7].p }
    else { s.cursor = lerp(clicks[7].p, NSPoint(x: 330, y: 330), smooth((t - 9.9) / 0.7)) }

    // Bulb.
    let names = ["Red", "Green", "Blue", "Purple"], picks = [0, 4, 7, 9]
    for (k, c) in clicks[1...4].enumerated() where t >= c.t { s.colour = swatches[picks[k]]; s.label = names[k] }
    if t >= 5.3 {
        let hue = (wheelAngle / (2 * .pi)).truncatingRemainder(dividingBy: 1)
        s.colour = NSColor(deviceHue: hue, saturation: wheelSat, brightness: 1, alpha: 1)
        s.label = "Colour wheel"
        s.wheelKnob = wheelPoint(wheelAngle, wheelSat)
    }
    s.brightness = brightnessAt(t) / 100
    if t >= 7.0 && t < 8.8 { s.label = "Brightness \(Int(brightnessAt(t).rounded()))%" }
    if t >= 8.8 {
        // Fireplace: warm flicker.
        let f = 0.5 + 0.25 * sin(t * 23) + 0.25 * sin(t * 37 + 1)
        s.colour = NSColor(red: 1, green: 0.32 + 0.18 * f, blue: 0.05, alpha: 1)
        s.brightness = 0.7 + 0.3 * f
        s.label = "Scene: Fireplace"
    }
    if t < 3.4 { s.colour = warmWhite; s.label = "Warm white" }
    return s
}

// MARK: Drawing

func text(_ s: String, _ p: NSPoint, size: CGFloat = 13, weight: NSFont.Weight = .regular, colour: NSColor = .white, alpha: CGFloat = 0.92) {
    (s as NSString).draw(at: p, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: colour.withAlphaComponent(alpha)])
}

func textCentred(_ s: String, _ y: CGFloat, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor.white.withAlphaComponent(alpha)]
    let w = (s as NSString).size(withAttributes: attrs).width
    (s as NSString).draw(at: NSPoint(x: (W - w) / 2, y: y), withAttributes: attrs)
}

func panel(_ r: NSRect) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.shadowBlurRadius = 20
    shadow.set()
    NSColor(red: 0.16, green: 0.16, blue: 0.19, alpha: 0.97).setFill()
    NSBezierPath(roundedRect: r, xRadius: 9, yRadius: 9).fill()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.12).setStroke()
    NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 9, yRadius: 9).stroke()
}

func row(_ label: String, _ r: NSRect, highlighted: Bool, submenu: Bool = false, check: Bool = false) {
    if highlighted {
        NSColor.controlAccentColor.usingColorSpace(.deviceRGB)!.setFill()
        NSBezierPath(roundedRect: r.insetBy(dx: 5, dy: 1), xRadius: 4, yRadius: 4).fill()
    }
    if check { text("✓", NSPoint(x: r.minX + 10, y: r.minY + 3)) }
    text(label, NSPoint(x: r.minX + 24, y: r.minY + 3))
    if submenu { text("›", NSPoint(x: r.maxX - 20, y: r.minY + 1), size: 15, alpha: 0.6) }
}

func separator(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat) {
    NSColor.white.withAlphaComponent(0.1).setFill()
    NSRect(x: x + 12, y: y + 4, width: w - 24, height: 1).fill()
}

func slider(_ label: String, _ y: CGFloat, _ value: CGFloat) {
    text(label, NSPoint(x: 664, y: y - 26), size: 12, alpha: 0.75)
    NSColor.white.withAlphaComponent(0.18).setFill()
    NSBezierPath(roundedRect: NSRect(x: trackX.lowerBound, y: y - 2, width: trackX.upperBound - trackX.lowerBound, height: 4), xRadius: 2, yRadius: 2).fill()
    NSColor.controlAccentColor.usingColorSpace(.deviceRGB)!.setFill()
    NSBezierPath(roundedRect: NSRect(x: trackX.lowerBound, y: y - 2, width: value - trackX.lowerBound, height: 4), xRadius: 2, yRadius: 2).fill()
    NSColor.white.setFill()
    NSBezierPath(ovalIn: NSRect(x: value - 8, y: y - 8, width: 16, height: 16)).fill()
}

let wheelImage: NSImage = {
    let px = 280
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let r = CGFloat(px) / 2
    for y in 0..<px { for x in 0..<px {
        let dx = CGFloat(x) - r, dy = r - CGFloat(y), d = (dx * dx + dy * dy).squareRoot()
        let hue = (atan2(dy, dx) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
        rep.setColor(d <= r ? NSColor(deviceHue: hue, saturation: d / r, brightness: 1, alpha: 1) : NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0), atX: x, y: y)
    } }
    let img = NSImage(size: NSSize(width: 140, height: 140))
    img.addRepresentation(rep)
    return img
}()

func drawFrame(_ t: Double) {
    let s = state(t)

    // Desktop.
    NSGradient(colors: [NSColor(red: 0.07, green: 0.08, blue: 0.13, alpha: 1), NSColor(red: 0.15, green: 0.1, blue: 0.22, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

    // Bulb with glow.
    let lit = s.colour.blended(withFraction: 1 - s.brightness, of: NSColor(white: 0.25, alpha: 1))!
    NSGradient(colors: [s.colour.withAlphaComponent(0.55 * s.brightness), s.colour.withAlphaComponent(0)])!
        .draw(fromCenter: bulbCentre, radius: 0, toCenter: bulbCentre, radius: 210, options: [])
    let cfg = NSImage.SymbolConfiguration(pointSize: 150, weight: .regular)
        .applying(.init(paletteColors: [lit.blended(withFraction: 0.35 * s.brightness, of: .white)!]))
    let bulb = NSImage(systemSymbolName: "lightbulb.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    bulb.draw(in: NSRect(x: bulbCentre.x - bulb.size.width / 2, y: bulbCentre.y - bulb.size.height / 2, width: bulb.size.width, height: bulb.size.height),
              from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 17, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.85)]
    let lw = (s.label as NSString).size(withAttributes: attrs).width
    (s.label as NSString).draw(at: NSPoint(x: bulbCentre.x - lw / 2, y: 410), withAttributes: attrs)

    // Menu bar.
    NSColor.black.withAlphaComponent(0.35).setFill()
    NSRect(x: 0, y: 0, width: W, height: 24).fill()
    if s.menu {
        NSColor.white.withAlphaComponent(0.2).setFill()
        NSBezierPath(roundedRect: NSRect(x: statusIcon.x - 13, y: 2, width: 26, height: 20), xRadius: 4, yRadius: 4).fill()
    }
    let barCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium).applying(.init(paletteColors: [.white]))
    let barIcon = NSImage(systemSymbolName: "lightbulb.max.fill", accessibilityDescription: nil)!.withSymbolConfiguration(barCfg)!
    barIcon.draw(in: NSRect(x: statusIcon.x - barIcon.size.width / 2, y: statusIcon.y - barIcon.size.height / 2, width: barIcon.size.width, height: barIcon.size.height),
                 from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    for (name, x) in [("wifi", 520.0), ("battery.75percent", 556.0)] {
        let i = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(barCfg)!
        i.draw(in: NSRect(x: x - i.size.width / 2, y: 12 - i.size.height / 2, width: i.size.width, height: i.size.height),
               from: .zero, operation: .sourceOver, fraction: 0.9, respectFlipped: true, hints: nil)
    }
    text("Sat 9:41 PM", NSPoint(x: 800, y: 4), alpha: 0.9)

    // Main menu.
    if s.menu {
        panel(mainMenu)
        var y = mainMenu.minY + 5
        for (i, item) in mainItems.enumerated() {
            if item == "-" { separator(mainMenu.minX, y, mainMenu.width); y += 9; continue }
            row(item, NSRect(x: mainMenu.minX, y: y, width: mainMenu.width, height: 22),
                highlighted: i == 0 && s.submenu, submenu: i < 3, check: item == "Start at Login")
            y += 22
        }
    }

    // Bulb submenu.
    if s.submenu {
        panel(sub)
        row("On", NSRect(x: sub.minX, y: 31, width: sub.width, height: 22), highlighted: false)
        row("Off", NSRect(x: sub.minX, y: 53, width: sub.width, height: 22), highlighted: false)
        separator(sub.minX, 75, sub.width)
        slider("Brightness", brightnessY, sliderX(brightnessAt(t), 10, 100))
        slider("Warm ↔ Cool", tempY, sliderX(4000, 2200, 6500))
        separator(sub.minX, 172, sub.width)
        text("Colour", NSPoint(x: 664, y: 182), size: 12, alpha: 0.75)
        for (i, c) in swatches.enumerated() {
            let p = NSBezierPath(ovalIn: swatchRect(i))
            c.setFill(); p.fill()
            NSColor.white.withAlphaComponent(0.2).setStroke(); p.stroke()
        }
        wheelImage.draw(in: wheelRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if let k = s.wheelKnob {
            let ring = NSBezierPath(ovalIn: NSRect(x: k.x - 6, y: k.y - 6, width: 12, height: 12))
            ring.lineWidth = 2
            NSColor.white.setStroke(); ring.stroke()
        }
        separator(sub.minX, 417, sub.width)
        row("Scenes", scenesRow, highlighted: s.scenes, submenu: true)
    }

    // Scenes submenu.
    if s.scenes {
        panel(scenesMenu)
        for (i, n) in sceneNames.enumerated() { row(n, sceneRow(i), highlighted: i == 2 && s.fireplaceHover) }
    }

    // Click ripple.
    for c in clicks where t >= c.t && t < c.t + 0.35 {
        let k = CGFloat((t - c.t) / 0.35), r = 6 + 16 * k
        let ring = NSBezierPath(ovalIn: NSRect(x: c.p.x - r, y: c.p.y - r, width: 2 * r, height: 2 * r))
        ring.lineWidth = 2
        NSColor.white.withAlphaComponent(0.8 * (1 - k)).setStroke(); ring.stroke()
    }

    // Cursor.
    // NSCursor images do not draw off screen, so draw the arrow.
    let arrow = NSBezierPath()
    arrow.move(to: s.cursor)
    for (dx, dy) in [(0.0, 17.0), (4.0, 13.0), (7.0, 20.0), (10.0, 19.0), (7.0, 12.0), (12.0, 12.0)] {
        arrow.line(to: NSPoint(x: s.cursor.x + dx, y: s.cursor.y + dy))
    }
    arrow.close()
    arrow.lineJoinStyle = .round
    arrow.lineWidth = 1.5
    NSGraphicsContext.current?.saveGraphicsState()
    let cursorShadow = NSShadow()
    cursorShadow.shadowColor = NSColor.black.withAlphaComponent(0.4)
    cursorShadow.shadowOffset = NSSize(width: 0, height: -1)
    cursorShadow.shadowBlurRadius = 2
    cursorShadow.set()
    NSColor.white.setStroke(); arrow.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    NSColor.black.setFill(); arrow.fill()

    // Title card at the start and end, so the loop is seamless.
    if s.card > 0 {
        NSColor(red: 0.07, green: 0.08, blue: 0.13, alpha: s.card).setFill()
        NSRect(x: 0, y: 0, width: W, height: H).fill()
        icon.draw(in: NSRect(x: (W - 150) / 2, y: 110, width: 150, height: 150), from: .zero, operation: .sourceOver, fraction: s.card, respectFlipped: true, hints: nil)
        textCentred("Lumo", 270, size: 46, weight: .bold, alpha: s.card)
        textCentred("Control your WiZ lights from the Mac menu bar", 336, size: 19, weight: .regular, alpha: 0.75 * s.card)
    }
}

// MARK: Render

let frames = Int(duration * fps)
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, frames, nil)!
CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
let frameProps = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
for f in 0..<frames {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let cg = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    cg.translateBy(x: 0, y: H)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    drawFrame(Double(f) / fps)
    NSGraphicsContext.current = nil
    // GIF has 256 colours, so gradients band. A fixed 4x4 Bayer pattern hides the bands
    // and stays the same in every frame, so it does not flicker.
    let bayer: [Int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    let px = rep.bitmapData!, stride = rep.bytesPerRow, wheelShown = state(Double(f) / fps).submenu
    for y in 0..<Int(H) { for x in 0..<Int(W) {
        // The wheel has the most hues, so it gets a stronger dither.
        let strength = wheelShown && wheelRect.contains(NSPoint(x: x, y: y)) ? 2.0 : 0.75
        let o = y * stride + x * 4, n = Int(Double(bayer[(y & 3) * 4 + (x & 3)] - 8) * strength)
        for c in 0..<3 { px[o + c] = UInt8(clamping: Int(px[o + c]) + n) }
    } }
    CGImageDestinationAddImage(dest, rep.cgImage!, frameProps)
}
precondition(CGImageDestinationFinalize(dest), "GIF write failed")
