import SwiftUI

struct DiceFaceView: View {
    @Binding var face: Int // 1...6
    let size: CGFloat = 46

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
            let dieBlue = Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)

            // White filled rounded rect, inset 2pt on each side.
            let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
            let rr = Path(roundedRect: rect, cornerRadius: 9)
            ctx.fill(rr, with: .color(.white))

            // Blue pips (radius 3.2) in a 44×44 viewBox coordinates.
            let dots = pipPositions[clampedFace] ?? pipPositions[1]!
            for (x, y) in dots {
                let pip = CGRect(x: x - 3.2, y: y - 3.2, width: 6.4, height: 6.4)
                ctx.fill(Path(ellipseIn: pip), with: .color(dieBlue))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var clampedFace: Int {
        min(6, max(1, face))
    }
}

