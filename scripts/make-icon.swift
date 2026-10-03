// Gera o ícone do app (estilo steampunk): moldura de madeira, placa de latão com
// rebites, engrenagem de cobre e uma válvula acesa sobre um teclado de piano.
// Uso: swift scripts/make-icon.swift <saída sem extensão>   → <saída>.iconset/
import AppKit

let out = CommandLine.arguments[1]
let iconset = out + ".iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
let brassLight = rgb(0.95, 0.80, 0.48), brassMid = rgb(0.78, 0.59, 0.29), brassDark = rgb(0.45, 0.31, 0.12)
let copper = rgb(0.74, 0.43, 0.22), copperDark = rgb(0.42, 0.22, 0.10)
let woodLight = rgb(0.40, 0.22, 0.11), woodDark = rgb(0.15, 0.07, 0.03)
let glow = rgb(1.0, 0.56, 0.16)

func gearPath(center c: CGPoint, outer: CGFloat, teeth: Int, rotation: CGFloat) -> NSBezierPath {
    let inner = outer * 0.80
    let p = NSBezierPath()
    let step = CGFloat.pi * 2 / CGFloat(teeth)
    for i in 0..<teeth {
        let a = CGFloat(i) * step + rotation
        let pts: [(CGFloat, CGFloat)] = [(a, inner), (a + step * 0.12, outer), (a + step * 0.42, outer), (a + step * 0.54, inner)]
        for (j, (ang, r)) in pts.enumerated() {
            let pt = CGPoint(x: c.x + cos(ang) * r, y: c.y + sin(ang) * r)
            if i == 0 && j == 0 { p.move(to: pt) } else { p.line(to: pt) }
        }
    }
    p.close()
    // furo central e janelas entre os raios
    p.appendOval(in: CGRect(x: c.x - outer * 0.16, y: c.y - outer * 0.16, width: outer * 0.32, height: outer * 0.32))
    for k in 0..<6 {
        let a = CGFloat(k) * .pi / 3 + rotation
        let r = outer * 0.50, h = outer * 0.17
        p.appendOval(in: CGRect(x: c.x + cos(a) * r - h, y: c.y + sin(a) * r - h, width: h * 2, height: h * 2))
    }
    p.windingRule = .evenOdd
    return p
}

func draw(size s: CGFloat) {
    let ctx = NSGraphicsContext.current!.cgContext
    // Grade de ícone do macOS: forma de 824/1024 com raio ~185/1024
    let inset = s * 100 / 1024
    let frame = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = frame.width * 0.225

    // sombra projetada
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    let outerShape = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    woodDark.setFill(); outerShape.fill()
    ctx.restoreGState()

    // moldura de madeira com veios
    NSGradient(colors: [woodLight, woodDark, woodLight, woodDark])!.draw(in: outerShape, angle: -60)
    ctx.saveGState()
    outerShape.addClip()
    for i in 0..<40 {
        let y = frame.minY + CGFloat(i) / 40 * frame.height
        let p = NSBezierPath()
        p.move(to: CGPoint(x: frame.minX, y: y))
        p.curve(to: CGPoint(x: frame.maxX, y: y + CGFloat((i % 5) - 2) * s * 0.004),
                controlPoint1: CGPoint(x: frame.minX + frame.width * 0.3, y: y + CGFloat(i % 3) * s * 0.006 - s * 0.006),
                controlPoint2: CGPoint(x: frame.minX + frame.width * 0.7, y: y - CGFloat(i % 4) * s * 0.004 + s * 0.006))
        p.lineWidth = i % 4 == 0 ? s * 0.0025 : s * 0.001
        NSColor.black.withAlphaComponent(0.22).setStroke(); p.stroke()
    }
    ctx.restoreGState()

    // placa de latão
    let plate = frame.insetBy(dx: frame.width * 0.075, dy: frame.width * 0.075)
    let plateR = radius * 0.72
    let platePath = NSBezierPath(roundedRect: plate, xRadius: plateR, yRadius: plateR)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.006), blur: s * 0.012, color: NSColor.black.withAlphaComponent(0.6).cgColor)
    brassMid.setFill(); platePath.fill()
    ctx.restoreGState()
    NSGradient(colors: [brassLight, brassMid, rgb(0.86, 0.69, 0.38), brassDark])!.draw(in: platePath, angle: -50)
    // escovado
    ctx.saveGState()
    platePath.addClip()
    var y = plate.minY
    var n = 0
    while y < plate.maxY {
        let p = NSBezierPath(); p.move(to: CGPoint(x: plate.minX, y: y)); p.line(to: CGPoint(x: plate.maxX, y: y))
        p.lineWidth = max(0.5, s * 0.001)
        NSColor.white.withAlphaComponent(n % 3 == 0 ? 0.07 : 0.025).setStroke(); p.stroke()
        y += max(1, s * 0.004); n += 1
    }
    ctx.restoreGState()
    brassDark.setStroke(); platePath.lineWidth = s * 0.006; platePath.stroke()

    // rebites
    let rv = s * 0.026
    for (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
        let cx = plate.minX + plate.width * 0.09 + (plate.width * 0.82) * dx
        let cy = plate.minY + plate.height * 0.09 + (plate.height * 0.82) * dy
        let r = NSBezierPath(ovalIn: CGRect(x: cx - rv, y: cy - rv, width: rv * 2, height: rv * 2))
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: s * 0.002, height: -s * 0.003), blur: s * 0.004, color: NSColor.black.withAlphaComponent(0.5).cgColor)
        brassMid.setFill(); r.fill()
        ctx.restoreGState()
        NSGradient(colors: [brassLight, brassMid, brassDark])!.draw(in: r, relativeCenterPosition: NSPoint(x: -0.35, y: 0.35))
    }

    ctx.saveGState()
    platePath.addClip()

    // engrenagens de cobre ao fundo
    let gearC = CGPoint(x: plate.midX + plate.width * 0.17, y: plate.midY + plate.height * 0.12)
    let big = gearPath(center: gearC, outer: plate.width * 0.36, teeth: 14, rotation: 0.1)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.004), blur: s * 0.01, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    copper.setFill(); big.fill()
    ctx.restoreGState()
    NSGradient(colors: [copper, copperDark])!.draw(in: big, angle: -90)
    copperDark.setStroke(); big.lineWidth = s * 0.003; big.stroke()

    let smallC = CGPoint(x: plate.minX + plate.width * 0.22, y: plate.maxY - plate.height * 0.22)
    let small = gearPath(center: smallC, outer: plate.width * 0.15, teeth: 10, rotation: 0.3)
    NSGradient(colors: [brassMid, brassDark])!.draw(in: small, angle: -90)
    brassDark.setStroke(); small.lineWidth = s * 0.002; small.stroke()

    // teclado de piano (base)
    let kb = CGRect(x: plate.minX, y: plate.minY, width: plate.width, height: plate.height * 0.20)
    NSGradient(colors: [rgb(0.97, 0.95, 0.88), rgb(0.82, 0.79, 0.70)])!.draw(in: NSBezierPath(rect: kb), angle: -90)
    let whites = 9
    let kw = kb.width / CGFloat(whites)
    for i in 1..<whites {
        let l = NSBezierPath(); l.move(to: CGPoint(x: kb.minX + CGFloat(i) * kw, y: kb.minY)); l.line(to: CGPoint(x: kb.minX + CGFloat(i) * kw, y: kb.maxY))
        l.lineWidth = max(0.5, s * 0.002); rgb(0.35, 0.30, 0.25).setStroke(); l.stroke()
    }
    for i in [0, 1, 3, 4, 5, 7] {
        let bx = kb.minX + CGFloat(i + 1) * kw - kw * 0.3
        let bk = NSBezierPath(roundedRect: CGRect(x: bx, y: kb.minY + kb.height * 0.38, width: kw * 0.6, height: kb.height * 0.62), xRadius: s * 0.004, yRadius: s * 0.004)
        NSGradient(colors: [rgb(0.25, 0.22, 0.20), rgb(0.05, 0.04, 0.03)])!.draw(in: bk, angle: -90)
    }
    // friso de latão sobre o teclado
    let rail = CGRect(x: kb.minX, y: kb.maxY - s * 0.004, width: kb.width, height: s * 0.022)
    NSGradient(colors: [brassLight, brassDark])!.draw(in: NSBezierPath(rect: rail), angle: -90)
    ctx.restoreGState()

    // válvula
    let tw = plate.width * 0.30, th = plate.height * 0.50
    let tx = plate.midX - tw / 2 - plate.width * 0.04
    let baseH = plate.height * 0.09
    let baseY = kb.maxY + s * 0.018
    let glassRect = CGRect(x: tx, y: baseY + baseH * 0.8, width: tw, height: th)

    // halo
    let halo = NSGradient(colors: [glow.withAlphaComponent(0.95), glow.withAlphaComponent(0.35), glow.withAlphaComponent(0.0)])!
    let hc = CGPoint(x: glassRect.midX, y: glassRect.minY + th * 0.42)
    halo.draw(fromCenter: hc, radius: 0, toCenter: hc, radius: tw * 1.45, options: [])

    // base de baquelite
    let base = NSBezierPath(roundedRect: CGRect(x: tx - tw * 0.08, y: baseY, width: tw * 1.16, height: baseH), xRadius: s * 0.012, yRadius: s * 0.012)
    NSGradient(colors: [rgb(0.22, 0.20, 0.19), rgb(0.04, 0.04, 0.04)])!.draw(in: base, angle: -90)
    // anel de latão
    let ring = NSBezierPath(rect: CGRect(x: tx - tw * 0.02, y: baseY + baseH * 0.78, width: tw * 1.04, height: s * 0.016))
    NSGradient(colors: [brassLight, brassDark])!.draw(in: ring, angle: -90)

    // envelope de vidro (topo arredondado)
    let gr = tw / 2
    let glass = NSBezierPath()
    glass.move(to: CGPoint(x: glassRect.minX, y: glassRect.minY))
    glass.line(to: CGPoint(x: glassRect.minX, y: glassRect.maxY - gr))
    glass.appendArc(withCenter: CGPoint(x: glassRect.midX, y: glassRect.maxY - gr), radius: gr, startAngle: 180, endAngle: 0, clockwise: true)
    glass.line(to: CGPoint(x: glassRect.maxX, y: glassRect.minY))
    glass.close()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.30), NSColor.white.withAlphaComponent(0.06), NSColor.white.withAlphaComponent(0.22)])!.draw(in: glass, angle: 0)

    ctx.saveGState()
    glass.addClip()
    // brilho interno
    let inner = NSGradient(colors: [rgb(1.0, 0.85, 0.5), glow.withAlphaComponent(0.9), glow.withAlphaComponent(0.0)])!
    let ic = CGPoint(x: glassRect.midX, y: glassRect.minY + th * 0.40)
    inner.draw(fromCenter: ic, radius: 0, toCenter: ic, radius: tw * 0.75, options: [])
    // placas internas
    for k in [-1.0, 1.0] {
        let pr = CGRect(x: glassRect.midX + CGFloat(k) * tw * 0.22 - tw * 0.08, y: glassRect.minY + th * 0.14, width: tw * 0.16, height: th * 0.50)
        NSGradient(colors: [rgb(0.55, 0.55, 0.55), rgb(0.25, 0.25, 0.25)])!.draw(in: NSBezierPath(roundedRect: pr, xRadius: s * 0.004, yRadius: s * 0.004), angle: 0)
    }
    // filamento
    let fil = NSBezierPath(roundedRect: CGRect(x: glassRect.midX - tw * 0.05, y: glassRect.minY + th * 0.10, width: tw * 0.10, height: th * 0.60), xRadius: tw * 0.05, yRadius: tw * 0.05)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.04, color: glow.cgColor)
    rgb(1.0, 0.75, 0.35).setFill(); fil.fill(); fil.fill()
    NSGradient(colors: [rgb(1.0, 0.97, 0.85), rgb(1.0, 0.70, 0.30)])!.draw(in: fil, angle: -90)
    ctx.restoreGState()
    // getter prateado no topo
    let getter = NSBezierPath(ovalIn: CGRect(x: glassRect.midX - tw * 0.30, y: glassRect.maxY - gr * 0.85, width: tw * 0.60, height: gr * 0.35))
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), rgb(0.6, 0.6, 0.65, 0.35)])!.draw(in: getter, angle: -90)
    ctx.restoreGState()

    // reflexo e contorno do vidro
    let refl = NSBezierPath(roundedRect: CGRect(x: glassRect.minX + tw * 0.12, y: glassRect.minY + th * 0.22, width: tw * 0.08, height: th * 0.55), xRadius: tw * 0.04, yRadius: tw * 0.04)
    NSColor.white.withAlphaComponent(0.45).setFill(); refl.fill()
    NSColor.white.withAlphaComponent(0.45).setStroke(); glass.lineWidth = s * 0.004; glass.stroke()
}

for (size, scale) in [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)] {
    let px = size * scale
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(size: CGFloat(px))
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)" + (scale == 2 ? "@2x" : "") + ".png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
}
