// Gera Resources/AppIcon.icns a partir do símbolo SF "pianokeys".
import AppKit
let out = CommandLine.arguments[1]
let iconset = out + ".iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
for (size, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let px = CGFloat(size * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let inset = px * 0.1, rect = NSRect(x: inset, y: inset, width: px - 2*inset, height: px - 2*inset)
    let bg = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(starting: NSColor(red: 0.16, green: 0.18, blue: 0.24, alpha: 1),
               ending: NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1))!.draw(in: bg, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: px * 0.42, weight: .regular)
        .applying(.init(paletteColors: [.white]))
    if let sym = NSImage(systemSymbolName: "pianokeys", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let s = sym.size
        sym.draw(in: NSRect(x: (px - s.width)/2, y: (px - s.height)/2, width: s.width, height: s.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
