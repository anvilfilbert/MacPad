// Render crisp, Retina-aware installation artwork using native graphics only.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ArtworkError: Error {
    case invalidArguments
    case unavailableGraphicsContext
    case unavailableImage
    case unavailableText
    case cannotWriteImage
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

func drawText(
    _ value: String, at point: CGPoint, size: CGFloat, font: String,
    color: CGColor, context: CGContext
) throws {
    guard let text = CFAttributedStringCreateMutable(nil, 0)
    else { throw ArtworkError.unavailableText }
    CFAttributedStringReplaceString(text, CFRange(location: 0, length: 0), value as CFString)
    let range = CFRange(location: 0, length: CFStringGetLength(value as CFString))
    CFAttributedStringSetAttribute(text, range, kCTFontAttributeName, CTFontCreateWithName(font as CFString, size, nil))
    CFAttributedStringSetAttribute(text, range, kCTForegroundColorAttributeName, color)
    context.textPosition = point
    CTLineDraw(CTLineCreateWithAttributedString(text), context)
}

func renderBackground(output: URL, scale: Int) throws {
    let width = 720 * scale
    let height = 440 * scale
    guard let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw ArtworkError.unavailableGraphicsContext }
    context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    let charcoal = color(25, 29, 31)
    let cream = color(247, 241, 228)
    let cyan = color(71, 219, 230)
    let secondary = color(175, 185, 185)
    context.setFillColor(charcoal)
    context.fill(CGRect(x: 0, y: 0, width: 720, height: 440))
    context.setFillColor(cyan)
    context.fill(CGRect(x: 52, y: 399, width: 32, height: 3))
    try drawText("MacPad", at: CGPoint(x: 50, y: 342), size: 44,
             font: "HelveticaNeue-Bold", color: cream, context: context)
    try drawText("Plain text. Ultra fast. No bloat.", at: CGPoint(x: 53, y: 313), size: 17,
             font: "HelveticaNeue", color: secondary, context: context)
    context.setStrokeColor(cyan)
    context.setLineWidth(3)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    context.move(to: CGPoint(x: 321, y: 217))
    context.addLine(to: CGPoint(x: 398, y: 217))
    context.move(to: CGPoint(x: 385, y: 230))
    context.addLine(to: CGPoint(x: 398, y: 217))
    context.addLine(to: CGPoint(x: 385, y: 204))
    context.strokePath()
    try drawText("Drag MacPad to Applications.", at: CGPoint(x: 226, y: 89), size: 18,
             font: "HelveticaNeue-Medium", color: cream, context: context)
    try drawText("Zum Installieren in „Programme“ ziehen.", at: CGPoint(x: 227, y: 65), size: 13,
             font: "HelveticaNeue", color: secondary, context: context)
    context.setFillColor(color(51, 59, 61))
    context.fill(CGRect(x: 52, y: 43, width: 616, height: 1))
    try drawText("macpad.net", at: CGPoint(x: 53, y: 22), size: 11,
             font: "HelveticaNeue-Medium", color: cyan, context: context)
    try drawText("Apple Silicon + Intel · macOS 14+", at: CGPoint(x: 484, y: 22), size: 11,
             font: "HelveticaNeue", color: secondary, context: context)
    guard let image = context.makeImage() else { throw ArtworkError.unavailableImage }
    guard let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw ArtworkError.cannotWriteImage }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw ArtworkError.cannotWriteImage }
}

guard CommandLine.arguments.count == 3,
      let scale = Int(CommandLine.arguments[2]), [1, 2].contains(scale)
else { throw ArtworkError.invalidArguments }
try renderBackground(output: URL(fileURLWithPath: CommandLine.arguments[1]), scale: scale)
