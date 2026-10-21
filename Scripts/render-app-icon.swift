#!/usr/bin/env swift
// Run from the repository root: swift Scripts/render-app-icon.swift
// Add --preview to also render a comparison at native 60 px and 29 px sizes.
// All drawing is procedural CoreGraphics. No fonts, assets, or icon masks.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let outputDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().appendingPathComponent("icon-candidates", isDirectory: true)

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace, components: [
        CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255,
        CGFloat(hex & 255) / 255, alpha
    ])!
}

func context(width: Int = size, height: Int = size) -> CGContext {
    // No alpha channel: even antialiased edges are composited onto opaque RGB.
    let bitmap = CGContext(data: nil, width: width, height: height,
                           bitsPerComponent: 8, bytesPerRow: width * 4,
                           space: colorSpace,
                           bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    bitmap.translateBy(x: 0, y: CGFloat(height))
    bitmap.scaleBy(x: 1, y: -1)
    bitmap.setAllowsAntialiasing(true)
    bitmap.setShouldAntialias(true)
    return bitmap
}

func polygon(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    return path
}

func fill(_ ctx: CGContext, _ path: CGPath, _ hex: UInt32) {
    ctx.addPath(path)
    ctx.setFillColor(color(hex))
    ctx.fillPath()
}

func gradient(_ ctx: CGContext, colors: [UInt32], from: CGPoint, to: CGPoint,
              within path: CGPath? = nil) {
    ctx.saveGState()
    if let path { ctx.addPath(path); ctx.clip() }
    let ramp = CGGradient(colorsSpace: colorSpace,
                          colors: colors.map { color($0) } as CFArray,
                          locations: nil)!
    ctx.drawLinearGradient(ramp, start: from, end: to,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func shadow(_ ctx: CGContext, path: CGPath, opacity: CGFloat = 0.2,
            blur: CGFloat = 30, offset: CGFloat = 16) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: offset), blur: blur,
                  color: color(0x03121D, alpha: opacity))
    fill(ctx, path, 0x132F40)
    ctx.restoreGState()
}

func arch(radius: CGFloat, springY: CGFloat, bottom: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 512 - radius, y: bottom))
    path.addLine(to: CGPoint(x: 512 - radius, y: springY))
    path.addArc(center: CGPoint(x: 512, y: springY), radius: radius,
                startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    path.addLine(to: CGPoint(x: 512 + radius, y: bottom))
    path.closeSubpath()
    return path
}

// 1. The anchor: a single broad crown stone, with a shallow arched underside.
// Large planes give it a little material depth without adding another symbol.
func drawAnchor(_ ctx: CGContext) {
    gradient(ctx, colors: [0x203F58, 0x0C2035],
             from: CGPoint(x: 100, y: 0), to: CGPoint(x: 900, y: 1024))
    let stone = CGMutablePath()
    stone.move(to: CGPoint(x: 249, y: 252))
    stone.addLine(to: CGPoint(x: 775, y: 252))
    stone.addLine(to: CGPoint(x: 654, y: 770))
    stone.addQuadCurve(to: CGPoint(x: 370, y: 770), control: CGPoint(x: 512, y: 724))
    stone.closeSubpath()
    shadow(ctx, path: stone, opacity: 0.32, blur: 40, offset: 24)
    gradient(ctx, colors: [0xFFE6AE, 0xE5B360],
             from: CGPoint(x: 350, y: 252), to: CGPoint(x: 670, y: 780), within: stone)
    // A broad, quiet right bevel; the inset face stays legible at tiny sizes.
    fill(ctx, polygon([CGPoint(x: 775, y: 252), CGPoint(x: 654, y: 770),
                       CGPoint(x: 632, y: 737), CGPoint(x: 741, y: 282)]), 0xC68F45)
    fill(ctx, polygon([CGPoint(x: 249, y: 252), CGPoint(x: 775, y: 252),
                       CGPoint(x: 741, y: 282), CGPoint(x: 285, y: 282)]), 0xFFF0C9)
}

// 2. The load-bearing arch: five large voussoirs, with the two end stones
// continuing into the piers. Radial joints all converge on the same center.
func drawMasonry(_ ctx: CGContext) {
    gradient(ctx, colors: [0x21474F, 0x102D37],
             from: CGPoint(x: 0, y: 0), to: CGPoint(x: 850, y: 1024))
    let center = CGPoint(x: 512, y: 538)
    let outer: CGFloat = 310
    let inner: CGFloat = 173
    let gap: CGFloat = 0.024
    func point(_ r: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
    }
    for index in 0..<5 where index != 2 {
        let a = .pi + CGFloat(index) * .pi / 5 + (index == 0 ? 0 : gap)
        let b = .pi + CGFloat(index + 1) * .pi / 5 - (index == 4 ? 0 : gap)
        let stone = CGMutablePath()
        stone.move(to: point(outer, a))
        stone.addArc(center: center, radius: outer, startAngle: a, endAngle: b, clockwise: false)
        if index == 4 {
            stone.addLine(to: CGPoint(x: 822, y: 796))
            stone.addLine(to: CGPoint(x: 685, y: 796))
        }
        stone.addLine(to: point(inner, b))
        stone.addArc(center: center, radius: inner, startAngle: b, endAngle: a, clockwise: true)
        if index == 0 {
            stone.addLine(to: CGPoint(x: 339, y: 796))
            stone.addLine(to: CGPoint(x: 202, y: 796))
        }
        stone.closeSubpath()
        shadow(ctx, path: stone, opacity: 0.15, blur: 18, offset: 12)
        gradient(ctx, colors: [0xF1E9D7, 0xB5C3BE],
                 from: CGPoint(x: 320, y: 230), to: CGPoint(x: 690, y: 820), within: stone)
    }
    // The crown extends beyond both arch curves, making its structural role clear.
    let key = polygon([CGPoint(x: 411, y: 196), CGPoint(x: 613, y: 196),
                       CGPoint(x: 561, y: 382), CGPoint(x: 463, y: 382)])
    shadow(ctx, path: key, opacity: 0.18, blur: 16, offset: 10)
    gradient(ctx, colors: [0xFFE5A6, 0xE6B45E],
             from: CGPoint(x: 440, y: 196), to: CGPoint(x: 580, y: 382), within: key)
    fill(ctx, polygon([CGPoint(x: 411, y: 196), CGPoint(x: 613, y: 196),
                       CGPoint(x: 607, y: 216), CGPoint(x: 417, y: 216)]), 0xFFF0C6)
}

// 3. First light: a monolithic slate doorway on pale stone, with a warm opening
// and a single pool of light. The crown stone bridges the facade and opening.
func drawDoorway(_ ctx: CGContext) {
    gradient(ctx, colors: [0xF1EDE1, 0xC6D3D2],
             from: CGPoint(x: 160, y: 0), to: CGPoint(x: 850, y: 1024))
    let facade = arch(radius: 282, springY: 492, bottom: 788)
    shadow(ctx, path: facade, opacity: 0.17, blur: 30, offset: 18)
    gradient(ctx, colors: [0x345565, 0x183443],
             from: CGPoint(x: 310, y: 210), to: CGPoint(x: 720, y: 800), within: facade)
    let opening = arch(radius: 159, springY: 503, bottom: 788)
    gradient(ctx, colors: [0xFFF3CD, 0xF1CC83, 0xDBA65D],
             from: CGPoint(x: 512, y: 344), to: CGPoint(x: 512, y: 788), within: opening)
    let light = polygon([CGPoint(x: 353, y: 788), CGPoint(x: 671, y: 788),
                         CGPoint(x: 748, y: 868), CGPoint(x: 276, y: 868)])
    gradient(ctx, colors: [0xE7BA73, 0xEFE0BC],
             from: CGPoint(x: 512, y: 788), to: CGPoint(x: 512, y: 868), within: light)
    let key = polygon([CGPoint(x: 427, y: 200), CGPoint(x: 597, y: 200),
                       CGPoint(x: 558, y: 358), CGPoint(x: 466, y: 358)])
    gradient(ctx, colors: [0xFFF1C9, 0xE4BA76],
             from: CGPoint(x: 460, y: 200), to: CGPoint(x: 570, y: 358), within: key)
}

func writePNG(_ image: CGImage, name: String) throws {
    let url = outputDirectory.appendingPathComponent(name)
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { throw NSError(domain: "KeystoneIcon", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "Cannot create \(url.path)"]) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "KeystoneIcon", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "Cannot write \(url.path)"])
    }
    print(url.path)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let drawings: [(CGContext) -> Void] = [drawAnchor, drawMasonry, drawDoorway]
var rendered: [CGImage] = []
for (index, draw) in drawings.enumerated() {
    let canvas = context()
    draw(canvas)
    let image = canvas.makeImage()!
    try writePNG(image, name: "candidate-\(index + 1).png")
    rendered.append(image)
}

if CommandLine.arguments.contains("--preview") {
    // Columns 1–3 match candidate numbers. Rows show 256, 60, and 29 px.
    let preview = context(width: 936, height: 460)
    preview.setFillColor(color(0xE4E7E9))
    preview.fill(CGRect(x: 0, y: 0, width: 936, height: 460))
    for (column, image) in rendered.enumerated() {
        for (edge, y) in [(256, 24), (60, 310), (29, 402)] {
            let x = column * 312 + (312 - edge) / 2
            preview.saveGState()
            preview.interpolationQuality = .high
            preview.translateBy(x: CGFloat(x), y: CGFloat(y + edge))
            preview.scaleBy(x: 1, y: -1)
            preview.draw(image, in: CGRect(x: 0, y: 0, width: edge, height: edge))
            preview.restoreGState()
        }
    }
    try writePNG(preview.makeImage()!, name: "size-preview.png")
}
