#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: frame-screenshot.swift <input.png> <output.png>\n".utf8))
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let sourceImage = NSImage(contentsOf: inputURL),
      let sourceRep = sourceImage.representations.first else {
    FileHandle.standardError.write(Data("Could not read input image.\n".utf8))
    exit(66)
}

let screenshotSize = NSSize(width: sourceRep.pixelsWide, height: sourceRep.pixelsHigh)
let padding: CGFloat = 38
let shadowInset: CGFloat = 12
let outputSize = NSSize(
    width: screenshotSize.width + padding * 2,
    height: screenshotSize.height + padding * 2
)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(outputSize.width),
    pixelsHigh: Int(outputSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Could not allocate output bitmap.\n".utf8))
    exit(74)
}

bitmap.size = outputSize
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

NSColor.black.setFill()
NSRect(origin: .zero, size: outputSize).fill()

let frameRect = NSRect(
    x: padding - shadowInset,
    y: padding - shadowInset,
    width: screenshotSize.width + shadowInset * 2,
    height: screenshotSize.height + shadowInset * 2
)
let frame = NSBezierPath(roundedRect: frameRect, xRadius: 26, yRadius: 26)
NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
frame.fill()

NSColor(calibratedWhite: 0.18, alpha: 1).setStroke()
frame.lineWidth = 1
frame.stroke()

let imageRect = NSRect(x: padding, y: padding, width: screenshotSize.width, height: screenshotSize.height)
sourceImage.draw(in: imageRect, from: NSRect(origin: .zero, size: screenshotSize), operation: .copy, fraction: 1)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("Could not render output image.\n".utf8))
    exit(74)
}

try pngData.write(to: outputURL)
