import AppKit

// Генерирует иконку приложения 1024×1024 и .iconset для iconutil.
// Запуск: swift Scripts/make_icon.swift

let pixelSize = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixelSize,
    pixelsHigh: pixelSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Не удалось создать bitmap")
}

NSGraphicsContext.saveGraphicsState()
guard let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Не удалось создать графический контекст")
}
NSGraphicsContext.current = graphicsContext

let canvas = NSRect(x: 0, y: 0, width: CGFloat(pixelSize), height: CGFloat(pixelSize))
NSColor.clear.setFill()
canvas.fill()

let inset: CGFloat = 58
let iconRect = canvas.insetBy(dx: inset, dy: inset)
let cornerRadius: CGFloat = 212
let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: cornerRadius, yRadius: cornerRadius)

// Мягкая тень под иконкой.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.shadowBlurRadius = 34
shadow.shadowOffset = NSSize(width: 0, height: -16)
shadow.set()

NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.82, alpha: 1).setFill()
iconPath.fill()

NSGraphicsContext.current?.saveGraphicsState()
iconPath.addClip()

// Градиент.
if let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.31, green: 0.23, blue: 0.85, alpha: 1),
    NSColor(calibratedRed: 0.51, green: 0.25, blue: 0.83, alpha: 1),
    NSColor(calibratedRed: 0.72, green: 0.30, blue: 0.72, alpha: 1)
]) {
    gradient.draw(in: iconPath, angle: -52)
}

// Мягкий верхний блик.
if let sheen = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.18),
    NSColor.white.withAlphaComponent(0.0)
]) {
    sheen.draw(in: iconPath, angle: -90)
}

NSColor.white.withAlphaComponent(0.14).setStroke()
iconPath.lineWidth = 3
iconPath.stroke()
NSGraphicsContext.current?.restoreGraphicsState()

// Рублик.
let font = NSFont.systemFont(ofSize: 470, weight: .bold)
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]

let text = NSAttributedString(string: "₽", attributes: attributes)
let textSize = text.size()
let textRect = NSRect(
    x: (CGFloat(pixelSize) - textSize.width) / 2,
    y: (CGFloat(pixelSize) - textSize.height) / 2 - 32,
    width: textSize.width,
    height: textSize.height
)

NSGraphicsContext.current?.saveGraphicsState()
let textShadow = NSShadow()
textShadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
textShadow.shadowBlurRadius = 18
textShadow.shadowOffset = NSSize(width: 0, height: -8)
textShadow.set()
text.draw(in: textRect)
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

// Сохранение.
let baseDirectory = URL(fileURLWithPath: "Assets", isDirectory: true)
try? FileManager.default.createDirectory(at: baseDirectory, withIntermediateDirectories: true)

let iconsetURL = baseDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Не удалось закодировать PNG")
}

let masterURL = baseDirectory.appendingPathComponent("AppIcon-1024.png")
try! pngData.write(to: masterURL)

struct IconSpec {
    let name: String
    let size: Int
}

let specs: [IconSpec] = [
    IconSpec(name: "icon_16x16.png", size: 16),
    IconSpec(name: "icon_16x16@2x.png", size: 32),
    IconSpec(name: "icon_32x32.png", size: 32),
    IconSpec(name: "icon_32x32@2x.png", size: 64),
    IconSpec(name: "icon_128x128.png", size: 128),
    IconSpec(name: "icon_128x128@2x.png", size: 256),
    IconSpec(name: "icon_256x256.png", size: 256),
    IconSpec(name: "icon_256x256@2x.png", size: 512),
    IconSpec(name: "icon_512x512.png", size: 512),
    IconSpec(name: "icon_512x512@2x.png", size: 1024)
]

for spec in specs {
    let target = iconsetURL.appendingPathComponent(spec.name)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
    process.arguments = ["-z", "\(spec.size)", "\(spec.size)", masterURL.path, "--out", target.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
}

print("Иконка сохранена: \(masterURL.path)")
