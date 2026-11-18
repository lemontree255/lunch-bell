import AppKit

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".iconset")
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let bounds = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        NSColor(calibratedRed: 0.96, green: 0.47, blue: 0.12, alpha: 1).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: CGFloat(pixels) * 0.06, dy: CGFloat(pixels) * 0.06),
                     xRadius: CGFloat(pixels) * 0.21, yRadius: CGFloat(pixels) * 0.21).fill()
        let symbol = NSImage(systemSymbolName: "fork.knife", accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixels) * 0.55, weight: .medium)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        let configured = symbol.withSymbolConfiguration(config)!
        let symbolSize = configured.size
        configured.draw(in: NSRect(x: (CGFloat(pixels) - symbolSize.width) / 2,
                                   y: (CGFloat(pixels) - symbolSize.height) / 2,
                                   width: symbolSize.width, height: symbolSize.height))
        NSGraphicsContext.restoreGraphicsState()
        let png = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", directory.path, "-o", CommandLine.arguments[1]]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
