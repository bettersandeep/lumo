// Lumo - menu bar control for WiZ bulbs over the local UDP API (port 38899).
// Build and install: ./build.sh
import AppKit
import ServiceManagement

let port: UInt16 = 38899

func sockaddrIn(_ ip: String) -> sockaddr_in {
    var a = sockaddr_in()
    a.sin_family = sa_family_t(AF_INET)
    a.sin_port = port.bigEndian
    inet_pton(AF_INET, ip, &a.sin_addr)
    return a
}

func udpSocket(timeout: Int = 0) -> Int32 {
    let fd = socket(AF_INET, SOCK_DGRAM, 0)
    var on: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
    var tv = timeval(tv_sec: timeout, tv_usec: 0)
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
    return fd
}

func send(_ fd: Int32, _ json: String, to ip: String) {
    var a = sockaddrIn(ip)
    let bytes = Array(json.utf8)
    withUnsafePointer(to: &a) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            _ = sendto(fd, bytes, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
}

// Subnet broadcast addresses; 255.255.255.255 gives "No route to host" on some Macs.
func broadcastAddresses() -> [String] {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0 else { return [] }
    defer { freeifaddrs(head) }
    var out: [String] = []
    var p = head
    while let i = p?.pointee {
        if i.ifa_addr?.pointee.sa_family == sa_family_t(AF_INET),
           Int32(i.ifa_flags) & IFF_BROADCAST != 0, Int32(i.ifa_flags) & IFF_LOOPBACK == 0,
           let b = i.ifa_dstaddr {
            var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            b.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { var s = $0.pointee.sin_addr; inet_ntop(AF_INET, &s, &buf, socklen_t(buf.count)) }
            out.append(String(cString: buf))
        }
        p = i.ifa_next
    }
    return out
}

struct Bulb { let ip: String, mac: String }

func discover() -> [Bulb] {
    let fd = udpSocket(timeout: 2)
    defer { close(fd) }
    // Some bulbs ignore broadcasts while in Wi-Fi power save, so also probe every host on the subnet.
    // ponytail: assumes a /24 home LAN, derive the range from the netmask if a bigger subnet shows up
    // Bulbs in power save drop some frames, so send 3 rounds.
    for _ in 1...3 {
        for b in broadcastAddresses() {
            send(fd, #"{"method":"getPilot","params":{}}"#, to: b)
            let prefix = b.split(separator: ".").dropLast().joined(separator: ".")
            for h in 1...254 { send(fd, #"{"method":"getPilot","params":{}}"#, to: "\(prefix).\(h)") }
        }
        usleep(300_000)
    }
    var found: [String: String] = [:]
    var buf = [UInt8](repeating: 0, count: 2048)
    var from = sockaddr_in()
    var len = socklen_t(MemoryLayout<sockaddr_in>.size)
    while case let n = withUnsafeMutablePointer(to: &from, { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(fd, &buf, buf.count, 0, $0, &len) } }), n > 0 {
        let reply = try? JSONSerialization.jsonObject(with: Data(buf[0..<n])) as? [String: Any]
        let ip = String(cString: inet_ntoa(from.sin_addr))
        found[ip] = (reply?["result"] as? [String: Any])?["mac"] as? String ?? ip
    }
    return found.map { Bulb(ip: $0.key, mac: $0.value) }.sorted { $0.ip < $1.ip }
}

// Scene IDs from the WiZ local API, checked on a bulb with setPilot sceneId.
let scenes: [(String, Int)] = [
    ("Ocean", 1), ("Romance", 2), ("Sunset", 3), ("Party", 4), ("Fireplace", 5), ("Cozy", 6),
    ("Forest", 7), ("Pastel Colours", 8), ("Wake Up", 9), ("Bedtime", 10), ("Warm White", 11),
    ("Daylight", 12), ("Cool White", 13), ("Night Light", 14), ("Focus", 15), ("Relax", 16),
    ("True Colours", 17), ("TV Time", 18), ("Plant Growth", 19), ("Spring", 20), ("Summer", 21),
    ("Fall", 22), ("Deep Dive", 23), ("Jungle", 24), ("Mojito", 25), ("Club", 26), ("Christmas", 27),
    ("Halloween", 28), ("Candlelight", 29), ("Golden White", 30), ("Pulse", 31), ("Steampunk", 32),
]

let swatches: [NSColor] = [
    .init(red: 1, green: 0, blue: 0, alpha: 1), .init(red: 1, green: 0.4, blue: 0, alpha: 1),
    .init(red: 1, green: 0.85, blue: 0, alpha: 1), .init(red: 0.5, green: 1, blue: 0, alpha: 1),
    .init(red: 0, green: 1, blue: 0, alpha: 1), .init(red: 0, green: 1, blue: 0.8, alpha: 1),
    .init(red: 0, green: 0.6, blue: 1, alpha: 1), .init(red: 0, green: 0, blue: 1, alpha: 1),
    .init(red: 0.45, green: 0, blue: 1, alpha: 1), .init(red: 0.8, green: 0, blue: 1, alpha: 1),
    .init(red: 1, green: 0, blue: 0.8, alpha: 1), .init(red: 1, green: 0.3, blue: 0.5, alpha: 1),
]

// Two rows of common colours. Click one to pick it.
class SwatchGrid: NSView {
    var onPick: (NSColor) -> Void = { _ in }
    let perRow = 6, d: CGFloat = 24, gap: CGFloat = 8

    func rect(_ i: Int) -> NSRect {
        let row = i / perRow, col = i % perRow
        return NSRect(x: CGFloat(col) * (d + gap), y: bounds.height - d - CGFloat(row) * (d + gap), width: d, height: d)
    }

    override func draw(_ dirty: NSRect) {
        for (i, c) in swatches.enumerated() {
            let p = NSBezierPath(ovalIn: rect(i))
            c.setFill(); p.fill()
            NSColor.separatorColor.setStroke(); p.stroke()
        }
    }

    override func mouseUp(with e: NSEvent) {
        let p = convert(e.locationInWindow, from: nil)
        if let i = swatches.indices.first(where: { rect($0).contains(p) }) { onPick(swatches[i]) }
    }
}

// Hue around the circle, saturation from the centre out. Click or drag to pick.
class ColorWheel: NSView {
    var onPick: (NSColor) -> Void = { _ in }
    var knob: NSPoint?
    var lastSent = Date.distantPast
    lazy var wheel: NSImage = NSImage(size: bounds.size, flipped: false) { r in
        let scale = 2, w = Int(r.width) * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: w, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for y in 0..<w { for x in 0..<w {
            let c = self.color(at: NSPoint(x: CGFloat(x) / CGFloat(scale), y: CGFloat(y) / CGFloat(scale))) ?? NSColor(deviceRed: 0, green: 0, blue: 0, alpha: 0)
            rep.setColor(c, atX: x, y: w - 1 - y)
        } }
        rep.draw(in: r)
        return true
    }

    func color(at p: NSPoint) -> NSColor? {
        let r = bounds.width / 2, dx = p.x - r, dy = p.y - r
        let d = (dx * dx + dy * dy).squareRoot()
        guard d <= r else { return nil }
        let hue = (atan2(dy, dx) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1)
        return NSColor(deviceHue: hue, saturation: d / r, brightness: 1, alpha: 1)
    }

    override func draw(_ dirty: NSRect) {
        wheel.draw(in: bounds)
        guard let k = knob else { return }
        let ring = NSBezierPath(ovalIn: NSRect(x: k.x - 6, y: k.y - 6, width: 12, height: 12))
        ring.lineWidth = 2
        NSColor.white.setStroke(); ring.stroke()
        NSColor.black.withAlphaComponent(0.4).setStroke(); NSBezierPath(ovalIn: ring.bounds.insetBy(dx: -1.5, dy: -1.5)).stroke()
    }

    func pick(_ e: NSEvent, force: Bool) {
        let p = convert(e.locationInWindow, from: nil)
        guard let c = color(at: p) else { return }
        knob = p
        needsDisplay = true
        // Throttle while dragging so the bulb is not flooded.
        if force || Date().timeIntervalSince(lastSent) > 0.08 { lastSent = Date(); onPick(c) }
    }

    override func mouseDown(with e: NSEvent) { pick(e, force: true) }
    override func mouseDragged(with e: NSEvent) { pick(e, force: false) }
    override func mouseUp(with e: NSEvent) { pick(e, force: true) }
}

class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let fd = udpSocket()
    var bulbs: [Bulb] = []
    // Aliases are keyed by MAC so they survive IP changes.
    var aliases: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "aliases") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "aliases") }
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        let icon = NSImage(systemSymbolName: "lightbulb.max.fill", accessibilityDescription: "Lumo")
        icon?.isTemplate = true
        item.button?.image = icon
        if !UserDefaults.standard.bool(forKey: "loginAsked") {
            UserDefaults.standard.set(true, forKey: "loginAsked")
            try? SMAppService.mainApp.register()
        }
        rediscover()
    }

    @objc func rediscover() {
        item.menu = NSMenu()
        item.menu?.addItem(withTitle: "Searching…", action: nil, keyEquivalent: "")
        DispatchQueue.global().async {
            let found = discover()
            DispatchQueue.main.async { self.bulbs = found; self.buildMenu() }
        }
    }

    func buildMenu() {
        let m = NSMenu()
        if bulbs.isEmpty { m.addItem(withTitle: "No bulbs found", action: nil, keyEquivalent: "") }
        if bulbs.count > 1 { addControls(m, title: "All lights", targets: bulbs.map(\.ip)) }
        for b in bulbs.sorted(by: { name($0) < name($1) }) {
            let sub = addControls(m, title: name(b), targets: [b.ip])
            sub.addItem(.separator())
            let rename = sub.addItem(withTitle: "Rename…", action: #selector(rename(_:)), keyEquivalent: "")
            rename.target = self
            rename.representedObject = b.mac
            sub.addItem(withTitle: "\(b.ip) · \(b.mac)", action: nil, keyEquivalent: "").isEnabled = false
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Rediscover", action: #selector(rediscover), keyEquivalent: "r").target = self
        let login = m.addItem(withTitle: "Start at Login", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        m.addItem(withTitle: "Quit Lumo", action: #selector(NSApp.terminate), keyEquivalent: "q")
        item.menu = m
    }

    @objc func toggleLogin(_ i: NSMenuItem) {
        if SMAppService.mainApp.status == .enabled { try? SMAppService.mainApp.unregister() } else { try? SMAppService.mainApp.register() }
        i.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func name(_ b: Bulb) -> String { aliases[b.mac] ?? b.ip }

    @objc func rename(_ i: NSMenuItem) {
        guard let mac = i.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = "Rename bulb"
        alert.informativeText = "Leave empty to show the IP address."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.stringValue = aliases[mac] ?? ""
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespaces)
        aliases[mac] = text.isEmpty ? nil : text
        buildMenu()
    }

    @discardableResult
    func addControls(_ m: NSMenu, title: String, targets: [String]) -> NSMenu {
        let sub = NSMenu()
        let action = { (label: String, params: String) in
            let i = sub.addItem(withTitle: label, action: #selector(self.fire(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = (targets, params)
        }
        action("On", #"{"state":true}"#)
        action("Off", #"{"state":false}"#)
        sub.addItem(.separator())
        sub.addItem(slider("Brightness", 10, 100, 100, targets) { #"{"dimming":\#($0)}"# })
        sub.addItem(slider("Warm ↔ Cool", 2200, 6500, 4000, targets) { #"{"temp":\#($0)}"# })
        sub.addItem(.separator())
        sub.addItem(wheel(targets))
        let sceneMenu = NSMenu()
        for (n, id) in scenes {
            let i = sceneMenu.addItem(withTitle: n, action: #selector(fire(_:)), keyEquivalent: "")
            i.target = self
            i.representedObject = (targets, #"{"sceneId":\#(id)}"#)
        }
        sub.addItem(withTitle: "Scenes", action: nil, keyEquivalent: "").submenu = sceneMenu
        m.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = sub
        return sub
    }

    func wheel(_ targets: [String]) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 276))
        let text = NSTextField(labelWithString: "Colour")
        text.frame = NSRect(x: 18, y: 256, width: 190, height: 16)
        let setColor = { (c: NSColor) in
            let rgb = c.usingColorSpace(.deviceRGB)!
            let r = Int(rgb.redComponent * 255), g = Int(rgb.greenComponent * 255), b = Int(rgb.blueComponent * 255)
            self.pilot(targets, #"{"r":\#(r),"g":\#(g),"b":\#(b)}"#)
        }
        let grid = SwatchGrid(frame: NSRect(x: 18, y: 188, width: 184, height: 56))
        grid.onPick = setColor
        let w = ColorWheel(frame: NSRect(x: 25, y: 8, width: 170, height: 170))
        w.onPick = setColor
        view.addSubview(text)
        view.addSubview(grid)
        view.addSubview(w)
        let i = NSMenuItem()
        i.view = view
        return i
    }

    func slider(_ label: String, _ lo: Double, _ hi: Double, _ v: Double, _ targets: [String], _ params: @escaping (Int) -> String) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 44))
        let text = NSTextField(labelWithString: label)
        text.frame = NSRect(x: 18, y: 24, width: 190, height: 16)
        let s = NSSlider(value: v, minValue: lo, maxValue: hi, target: self, action: #selector(slid(_:)))
        s.frame = NSRect(x: 18, y: 2, width: 190, height: 20)
        s.isContinuous = false
        objc_setAssociatedObject(s, &key, { (x: Int) in self.pilot(targets, params(x)) } as (Int) -> Void, .OBJC_ASSOCIATION_RETAIN)
        view.addSubview(text)
        view.addSubview(s)
        let i = NSMenuItem()
        i.view = view
        return i
    }

    @objc func slid(_ s: NSSlider) { (objc_getAssociatedObject(s, &key) as? (Int) -> Void)?(Int(s.doubleValue)) }

    @objc func fire(_ i: NSMenuItem) {
        guard let (targets, params) = i.representedObject as? ([String], String) else { return }
        pilot(targets, params)
    }

    func pilot(_ targets: [String], _ params: String) {
        for t in targets { send(fd, #"{"method":"setPilot","params":\#(params)}"#, to: t) }
    }
}

var key = 0
if CommandLine.arguments.contains("--discover") { discover().forEach { print($0.ip, $0.mac) }; exit(0) }
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
