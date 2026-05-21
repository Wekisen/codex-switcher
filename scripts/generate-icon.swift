import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Assets/CodexSwitcher.iconset", isDirectory: true)
let icnsURL = root.appendingPathComponent("Assets/CodexSwitcher.icns")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let scale = CGFloat(size) / 1024

    let background = NSBezierPath(
        roundedRect: rect.insetBy(dx: 80 * scale, dy: 80 * scale),
        xRadius: 210 * scale,
        yRadius: 210 * scale
    )
    NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.13, alpha: 1).setFill()
    background.fill()

    let inner = NSBezierPath(
        roundedRect: rect.insetBy(dx: 118 * scale, dy: 118 * scale),
        xRadius: 178 * scale,
        yRadius: 178 * scale
    )
    NSColor(calibratedRed: 0.12, green: 0.15, blue: 0.19, alpha: 1).setFill()
    inner.fill()

    func drawArrow(y: CGFloat, leftToRight: Bool) {
        let path = NSBezierPath()
        path.lineWidth = 58 * scale
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let startX = leftToRight ? 285 * scale : 739 * scale
        let endX = leftToRight ? 739 * scale : 285 * scale
        path.move(to: CGPoint(x: startX, y: y))
        path.line(to: CGPoint(x: endX, y: y))

        let head = 82 * scale
        if leftToRight {
            path.move(to: CGPoint(x: endX - head, y: y + head))
            path.line(to: CGPoint(x: endX, y: y))
            path.line(to: CGPoint(x: endX - head, y: y - head))
        } else {
            path.move(to: CGPoint(x: endX + head, y: y + head))
            path.line(to: CGPoint(x: endX, y: y))
            path.line(to: CGPoint(x: endX + head, y: y - head))
        }
        path.stroke()
    }

    NSColor(calibratedRed: 0.90, green: 0.96, blue: 1.0, alpha: 1).setStroke()
    drawArrow(y: 590 * scale, leftToRight: true)
    NSColor(calibratedRed: 0.26, green: 0.84, blue: 0.78, alpha: 1).setStroke()
    drawArrow(y: 430 * scale, leftToRight: false)

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to render \(name)")
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

let icnsChunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("icp5", "icon_32x32.png"),
    ("icp6", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic08", "icon_256x256.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

var body = Data()
for (type, filename) in icnsChunks {
    let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
    body.append(type.data(using: .macOSRoman)!)
    body.appendUInt32BE(UInt32(png.count + 8))
    body.append(png)
}

var icns = Data()
icns.append("icns".data(using: .macOSRoman)!)
icns.appendUInt32BE(UInt32(body.count + 8))
icns.append(body)
try icns.write(to: icnsURL)

private extension Data {
    mutating func appendUInt32BE(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xff))
        append(UInt8((value >> 16) & 0xff))
        append(UInt8((value >> 8) & 0xff))
        append(UInt8(value & 0xff))
    }
}
