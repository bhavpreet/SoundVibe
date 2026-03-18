#!/usr/bin/env swift
import AppKit

let width = 600
let height = 400

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

// Background gradient
let gradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.98, alpha: 1.0),
        NSColor.white,
    ]
)!
gradient.draw(
    in: NSRect(x: 0, y: 0, width: width, height: height),
    angle: 135
)

// "Drag to install" text
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .medium),
    .foregroundColor: NSColor(
        calibratedRed: 0.3, green: 0.3, blue: 0.35, alpha: 1.0
    ),
]
let title = "Drag to Applications to install"
let titleSize = title.size(withAttributes: titleAttrs)
title.draw(
    at: NSPoint(
        x: (CGFloat(width) - titleSize.width) / 2,
        y: 40
    ),
    withAttributes: titleAttrs
)

// Arrow pointing right (between icon positions)
let arrowAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 60, weight: .ultraLight),
    .foregroundColor: NSColor(
        calibratedRed: 0.5, green: 0.5, blue: 0.6, alpha: 0.6
    ),
]
let arrow = "→"
let arrowSize = arrow.size(withAttributes: arrowAttrs)
arrow.draw(
    at: NSPoint(
        x: (CGFloat(width) - arrowSize.width) / 2,
        y: (CGFloat(height) - arrowSize.height) / 2 - 10
    ),
    withAttributes: arrowAttrs
)

image.unlockFocus()

guard let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fprint("Failed to generate image")
    exit(1)
}

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/tmp/dmg_background.png"

try! pngData.write(to: URL(fileURLWithPath: outputPath))
print("Generated DMG background: \(outputPath)")

func fprint(_ msg: String) {
    FileHandle.standardError.write(Data((msg + "\n").utf8))
}
