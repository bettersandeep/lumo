// Draws the Lumo app icon: swift icon.swift out.png
import AppKit

let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { r in
    // macOS icon grid: 824pt rounded square centred in 1024.
    let tile = r.insetBy(dx: 100, dy: 100)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor.black.setFill(); shape.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [NSColor(red: 1.00, green: 0.72, blue: 0.25, alpha: 1),
                        NSColor(red: 0.98, green: 0.36, blue: 0.47, alpha: 1),
                        NSColor(red: 0.47, green: 0.29, blue: 0.95, alpha: 1)])!.draw(in: shape, angle: -60)

    // Soft glow behind the bulb.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 262, y: 300, width: 500, height: 500)), relativeCenterPosition: .zero)

    let cfg = NSImage.SymbolConfiguration(pointSize: 430, weight: .semibold).applying(.init(paletteColors: [.white]))
    let bulb = NSImage(systemSymbolName: "lightbulb.max.fill", accessibilityDescription: nil)!.withSymbolConfiguration(cfg)!
    let s = bulb.size
    bulb.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
    return true
}
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
