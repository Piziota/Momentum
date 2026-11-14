// Draws the app icon as a 1024px PNG. Run by build.sh, which turns it into an .icns.
import AppKit
import Foundation

let size = 1024.0
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }
ctx.setShouldAntialias(true)

// Squircle background with an indigo → violet gradient.
let inset = size * 0.085
let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = CGPath(roundedRect: rect,
                  cornerWidth: rect.width * 0.235,
                  cornerHeight: rect.height * 0.235,
                  transform: nil)

ctx.saveGState()
ctx.addPath(path)
ctx.clip()

let colours = [
    NSColor(srgbRed: 0.42, green: 0.48, blue: 1.00, alpha: 1).cgColor,
    NSColor(srgbRed: 0.66, green: 0.42, blue: 1.00, alpha: 1).cgColor
]
if let space = CGColorSpace(name: CGColorSpace.sRGB),
   let grad = CGGradient(colorsSpace: space, colors: colours as CFArray, locations: [0, 1]) {
    ctx.drawLinearGradient(grad,
                           start: CGPoint(x: rect.minX, y: rect.maxY),
                           end: CGPoint(x: rect.maxX, y: rect.minY),
                           options: [])
}

// Soft highlight across the top.
if let space = CGColorSpace(name: CGColorSpace.sRGB),
   let gloss = CGGradient(colorsSpace: space,
                          colors: [NSColor(white: 1, alpha: 0.26).cgColor,
                                   NSColor(white: 1, alpha: 0.0).cgColor] as CFArray,
                          locations: [0, 1]) {
    ctx.drawLinearGradient(gloss,
                           start: CGPoint(x: rect.midX, y: rect.maxY),
                           end: CGPoint(x: rect.midX, y: rect.midY),
                           options: [])
}
ctx.restoreGState()

// Lightning bolt, centred.
let w = size, h = size
func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * w, y: y * h) }

let bolt = CGMutablePath()
bolt.move(to: p(0.565, 0.845))
bolt.addLine(to: p(0.330, 0.470))
bolt.addLine(to: p(0.470, 0.470))
bolt.addLine(to: p(0.437, 0.155))
bolt.addLine(to: p(0.672, 0.530))
bolt.addLine(to: p(0.532, 0.530))
bolt.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
              blur: size * 0.03,
              color: NSColor(white: 0, alpha: 0.28).cgColor)
ctx.addPath(bolt)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try? png.write(to: URL(fileURLWithPath: out))
