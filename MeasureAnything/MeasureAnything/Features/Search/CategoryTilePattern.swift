import SwiftUI
import MeasureAnythingCore

/// Opacity applied to every category tile background pattern.
/// Tune this single value to make patterns more/less visible.
let kCategoryPatternOpacity: Double = 0.15

/// Draws a subtle, category-specific repeating pattern via `Canvas`.
/// Pass `category: nil` for the "All" tile (plus-mark grid).
struct CategoryTilePattern: View {
    let category: UnitCategory?
    let color: Color
    /// Stroke layer opacity (Explore tiles use `kCategoryPatternOpacity`).
    var patternOpacity: Double = kCategoryPatternOpacity

    var body: some View {
        Canvas { context, size in
            switch category {
            case .length:
                drawRulerTicks(context: context, size: size)
            case .mass:
                drawDotMatrix(context: context, size: size)
            case .time:
                drawClockTicks(context: context, size: size)
            case .temperature:
                drawScatteredDashes(context: context, size: size)
            case .volume:
                drawRippleArcs(context: context, size: size)
            case nil:
                drawPlusGrid(context: context, size: size)
            }
        }
        .allowsHitTesting(false)
        .opacity(patternOpacity)
    }

    // MARK: - Length: vertical ruler ticks

    private func drawRulerTicks(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 12
        let shortH: CGFloat = 6
        let tallH: CGFloat = 14
        let rowSpacing: CGFloat = 20
        let strokeW: CGFloat = 1.0

        var baseY: CGFloat = rowSpacing
        while baseY < size.height + rowSpacing {
            var x: CGFloat = spacing
            var index = 0
            while x < size.width + spacing {
                let h = index % 2 == 0 ? tallH : shortH
                var path = Path()
                path.move(to: CGPoint(x: x, y: baseY))
                path.addLine(to: CGPoint(x: x, y: baseY - h))
                context.stroke(path, with: .color(color), lineWidth: strokeW)
                x += spacing
                index += 1
            }
            baseY += rowSpacing
        }
    }

    // MARK: - Mass: dot matrix

    private func drawDotMatrix(context: GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 12
        let radius: CGFloat = 1.3

        var y: CGFloat = spacing / 2
        while y < size.height + spacing {
            var x: CGFloat = spacing / 2
            while x < size.width + spacing {
                let rect = CGRect(
                    x: x - radius, y: y - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(color))
                x += spacing
            }
            y += spacing
        }
    }

    // MARK: - Time: radial clock-face ticks

    private func drawClockTicks(context: GraphicsContext, size: CGSize) {
        let cellSize: CGFloat = 30
        let outerR: CGFloat = 12
        let innerRMajor: CGFloat = 8
        let innerRMinor: CGFloat = 9.5
        let strokeW: CGFloat = 1.0

        var cy: CGFloat = cellSize / 2
        while cy < size.height + cellSize {
            var cx: CGFloat = cellSize / 2
            while cx < size.width + cellSize {
                for i in 0..<12 {
                    let angle = Angle.degrees(Double(i) * 30 - 90)
                    let cosA = CGFloat(cos(angle.radians))
                    let sinA = CGFloat(sin(angle.radians))
                    let innerR = i % 3 == 0 ? innerRMajor : innerRMinor
                    var path = Path()
                    path.move(to: CGPoint(x: cx + innerR * cosA, y: cy + innerR * sinA))
                    path.addLine(to: CGPoint(x: cx + outerR * cosA, y: cy + outerR * sinA))
                    context.stroke(path, with: .color(color), lineWidth: strokeW)
                }
                cx += cellSize
            }
            cy += cellSize
        }
    }

    // MARK: - Temperature: scattered short horizontal dashes

    private func drawScatteredDashes(context: GraphicsContext, size: CGSize) {
        let cellSize: CGFloat = 12
        let dashW: CGFloat = 5
        let strokeW: CGFloat = 1.0
        let offsets: [(CGFloat, CGFloat)] = [(2, 3), (7, 7), (4, 10)]

        var y: CGFloat = 0
        while y < size.height + cellSize {
            var x: CGFloat = 0
            while x < size.width + cellSize {
                for (dx, dy) in offsets {
                    var path = Path()
                    path.move(to: CGPoint(x: x + dx, y: y + dy))
                    path.addLine(to: CGPoint(x: x + dx + dashW, y: y + dy))
                    context.stroke(path, with: .color(color), lineWidth: strokeW)
                }
                x += cellSize
            }
            y += cellSize
        }
    }

    // MARK: - Volume: concentric ripple arcs from bottom center

    private func drawRippleArcs(context: GraphicsContext, size: CGSize) {
        // Center slightly below the tile so the arc cap curves *into* the rect. A full
        // upper semicircle (180→0) with clockwise:true draws the lower half in y-down
        // coords and was fully clipped — hence the “empty” tile regression.
        let center = CGPoint(x: size.width / 2, y: size.height + 3)
        let spacing: CGFloat = 9
        let strokeW: CGFloat = 0.8
        let maxR = hypot(size.width / 2, size.height) + spacing * 2

        var r = spacing
        while r <= maxR {
            var path = Path()
            path.addArc(
                center: center, radius: r,
                startAngle: .degrees(195), endAngle: .degrees(345),
                clockwise: false
            )
            context.stroke(path, with: .color(color), lineWidth: strokeW)
            r += spacing
        }
    }

    // MARK: - All: plus-mark grid

    private func drawPlusGrid(context: GraphicsContext, size: CGSize) {
        let cellSize: CGFloat = 14
        let arm: CGFloat = 3
        let strokeW: CGFloat = 1.0

        var y: CGFloat = cellSize / 2
        while y < size.height + cellSize {
            var x: CGFloat = cellSize / 2
            while x < size.width + cellSize {
                var h = Path()
                h.move(to: CGPoint(x: x - arm, y: y))
                h.addLine(to: CGPoint(x: x + arm, y: y))
                context.stroke(h, with: .color(color), lineWidth: strokeW)

                var v = Path()
                v.move(to: CGPoint(x: x, y: y - arm))
                v.addLine(to: CGPoint(x: x, y: y + arm))
                context.stroke(v, with: .color(color), lineWidth: strokeW)

                x += cellSize
            }
            y += cellSize
        }
    }
}
