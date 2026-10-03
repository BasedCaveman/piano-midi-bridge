// Recorta o render escolhido (squircle sobre fundo cinza) e gera o ícone-mestre
// 1024×1024 com transparência na grade do macOS (forma de 824 px, sombra suave).
// Uso: swift scripts/make-icon-master.swift <render.png> <left> <top> <right> <bottom> <saída.png>
import AppKit
let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!
let rep = NSBitmapImageRep(data: src.tiffRepresentation!)!
let (l, t, r, b) = (CGFloat(Double(a[2])!), CGFloat(Double(a[3])!), CGFloat(Double(a[4])!), CGFloat(Double(a[5])!))
let H = CGFloat(rep.pixelsHigh)
let inset: CGFloat = 3 // descarta a borda serrilhada com o cinza
let srcRect = NSRect(x: l + inset, y: H - b + inset, width: r - l - inset * 2, height: b - t - inset * 2)

let S: CGFloat = 1024, shape: CGFloat = 824, radius: CGFloat = 0.215 * shape
let canvas = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
NSGraphicsContext.current?.imageInterpolation = .high
let dst = NSRect(x: (S - shape) / 2, y: (S - shape) / 2 + 6, width: shape, height: shape)
let path = NSBezierPath(roundedRect: dst, xRadius: radius, yRadius: radius)
// sombra
let ctx = NSGraphicsContext.current!.cgContext
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.35).cgColor)
NSColor.black.setFill(); path.fill()
ctx.restoreGState()
// arte
ctx.saveGState()
path.addClip()
src.draw(in: dst, from: srcRect, operation: .copy, fraction: 1)
ctx.restoreGState()
NSGraphicsContext.restoreGraphicsState()
try! canvas.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[6]))
