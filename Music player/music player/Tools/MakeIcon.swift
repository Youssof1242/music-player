import AppKit

let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard NSGraphicsContext.current != nil else { exit(1) }

let inset: CGFloat = 56
let backgroundRect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: backgroundRect, xRadius: 228, yRadius: 228)

let gradient = NSGradient(colors: [
    NSColor(srgbRed: 0.38, green: 0.27, blue: 0.95, alpha: 1),
    NSColor(srgbRed: 0.84, green: 0.25, blue: 0.60, alpha: 1)
])
gradient?.draw(in: path, angle: -65)

let config = NSImage.SymbolConfiguration(pointSize: 520, weight: .semibold)
if let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {

    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
    NSColor.white.set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let width = tinted.size.width
    let height = tinted.size.height
    let destRect = NSRect(
        x: (size - width) / 2,
        y: (size - height) / 2 - 18,
        width: width,
        height: height
    )
    tinted.draw(in: destRect, from: .zero, operation: .sourceOver, fraction: 1)
}

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/icon_1024.png"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
do {
    try png.write(to: outputURL)
    print("Icon written to \(outputPath)")
} catch {
    FileHandle.standardError.write(Data("Failed to write icon: \(error)\n".utf8))
    exit(1)
}
