#!/usr/bin/env swift
// 1024x1024 PNG 로고를 프로그램적으로 그린다.
// 컨셉: dark rounded rect 배경 + 흰 2x2 grid + 좌상단 프롬프트 `>_`.
// 실행: swift make-icon.swift → icon-1024.png 생성.

import AppKit

let size = 1024

guard let rep = NSBitmapImageRep(
  bitmapDataPlanes: nil,
  pixelsWide: size,
  pixelsHigh: size,
  bitsPerSample: 8,
  samplesPerPixel: 4,
  hasAlpha: true,
  isPlanar: false,
  colorSpaceName: .deviceRGB,
  bytesPerRow: 0,
  bitsPerPixel: 0
) else { fatalError("bitmap rep 생성 실패") }

NSGraphicsContext.saveGraphicsState()
let g = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = g
let ctx = g.cgContext

let s = CGFloat(size)

// 1. 배경 rounded rect (macOS 스타일 마스크).
let bgRect = CGRect(x: 96, y: 96, width: s - 192, height: s - 192)
let bgPath = CGPath(roundedRect: bgRect, cornerWidth: 180, cornerHeight: 180, transform: nil)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let bgColors = [
  CGColor(red: 0.14, green: 0.15, blue: 0.18, alpha: 1.0),
  CGColor(red: 0.06, green: 0.06, blue: 0.08, alpha: 1.0),
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1])!

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
ctx.drawLinearGradient(
  gradient,
  start: CGPoint(x: bgRect.minX, y: bgRect.maxY),
  end: CGPoint(x: bgRect.maxX, y: bgRect.minY),
  options: []
)
ctx.restoreGState()

// 은은한 상단 하이라이트.
ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let hlColors = [
  CGColor(red: 1, green: 1, blue: 1, alpha: 0.09),
  CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
] as CFArray
let hl = CGGradient(colorsSpace: colorSpace, colors: hlColors, locations: [0, 1])!
ctx.drawLinearGradient(
  hl,
  start: CGPoint(x: bgRect.midX, y: bgRect.maxY),
  end: CGPoint(x: bgRect.midX, y: bgRect.midY),
  options: []
)
ctx.restoreGState()

// 2. 2x2 grid pane (흰 라인).
let gridInset: CGFloat = 210
let gridRect = CGRect(
  x: gridInset,
  y: gridInset,
  width: s - gridInset * 2,
  height: s - gridInset * 2
)

let strokeW: CGFloat = 20
NSColor.white.setStroke()

let gridPath = NSBezierPath(roundedRect: gridRect, xRadius: 44, yRadius: 44)
gridPath.lineWidth = strokeW
gridPath.stroke()

let vLine = NSBezierPath()
vLine.move(to: CGPoint(x: gridRect.midX, y: gridRect.minY))
vLine.line(to: CGPoint(x: gridRect.midX, y: gridRect.maxY))
vLine.lineWidth = strokeW
vLine.stroke()

let hLine = NSBezierPath()
hLine.move(to: CGPoint(x: gridRect.minX, y: gridRect.midY))
hLine.line(to: CGPoint(x: gridRect.maxX, y: gridRect.midY))
hLine.lineWidth = strokeW
hLine.stroke()

// 3. 좌상단 pane 안에 프롬프트 `>_` (터미널 그린).
let font = NSFont.monospacedSystemFont(ofSize: 130, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
  .font: font,
  .foregroundColor: NSColor(red: 0.36, green: 0.90, blue: 0.55, alpha: 1.0),
]
let prompt = NSAttributedString(string: ">_", attributes: attrs)
let promptSize = prompt.size()
let promptOrigin = CGPoint(
  x: gridRect.minX + 40,
  y: gridRect.maxY - promptSize.height - 30
)
prompt.draw(at: promptOrigin)

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
  fatalError("PNG 인코딩 실패")
}

let outURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("icon-1024.png")
try data.write(to: outURL)
print("✅ 생성: \(outURL.path)")
