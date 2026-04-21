import SwiftUI

struct DiceFaceView: View {
    @Binding var face: Int // 1...6
    var faceColor: Color
    var pipOpacity: Double = 1
    var size: CGFloat = 56

    private let pipPositions: [Int: [(CGFloat, CGFloat)]] = [
        1: [(22, 22)],
        2: [(13, 13), (31, 31)],
        3: [(13, 13), (22, 22), (31, 31)],
        4: [(13, 13), (31, 13), (13, 31), (31, 31)],
        5: [(13, 13), (31, 13), (22, 22), (13, 31), (31, 31)],
        6: [(13, 13), (31, 13), (13, 22), (31, 22), (13, 31), (31, 31)],
    ]

    var body: some View {
        Canvas { ctx, _ in
            // Filled rounded rect, inset 2pt on each side.
            let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
            let rr = Path(roundedRect: rect, cornerRadius: size * 0.20)
            ctx.fill(rr, with: .color(faceColor))

            // White pips scaled from a 44×44 viewBox.
            let dots = pipPositions[clampedFace] ?? pipPositions[1]!
            let scale = size / 46
            let r = 3.2 * scale
            let insetShift = 0.5 * scale
            let insetR = max(0.1, r - 0.5 * scale) // ~1pt smaller diameter in source coords
            for (x, y) in dots {
                let sx = x * scale
                let sy = y * scale
                let pip = CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)
                ctx.opacity = pipOpacity
                ctx.fill(Path(ellipseIn: pip), with: .color(.white))

                // Subtle "inset" highlight to make pips feel pressed in.
                ctx.opacity = pipOpacity * 0.15
                let inset = CGRect(
                    x: sx - insetR + insetShift,
                    y: sy - insetR + insetShift,
                    width: insetR * 2,
                    height: insetR * 2
                )
                ctx.fill(Path(ellipseIn: inset), with: .color(.white))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var clampedFace: Int {
        min(6, max(1, face))
    }
}

