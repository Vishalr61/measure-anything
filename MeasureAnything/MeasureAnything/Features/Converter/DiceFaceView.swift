import SwiftUI

struct DiceFaceView: View {
    @Binding var face: Int // 1...6
    @Binding var isRolling: Bool

    private let pipPositions: [Int: [(CGFloat, CGFloat)]] = [
        1: [(26, 26)],
        2: [(14, 14), (38, 38)],
        3: [(14, 14), (26, 26), (38, 38)],
        4: [(14, 14), (38, 14), (14, 38), (38, 38)],
        5: [(14, 14), (38, 14), (26, 26), (14, 38), (38, 38)],
        6: [(14, 14), (38, 14), (14, 26), (38, 26), (14, 38), (38, 38)],
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white, lineWidth: 2.5)
                .frame(width: 46, height: 46)

            Canvas { context, size in
                let dots = pipPositions[clampedFace] ?? pipPositions[1]!
                for (x, y) in dots {
                    let rect = CGRect(x: x - 4.2, y: y - 4.2, width: 8.4, height: 8.4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                }
            }
            .frame(width: 52, height: 52)
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }

    private var clampedFace: Int {
        min(6, max(1, face))
    }
}

