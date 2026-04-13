import SwiftUI
import UIKit

struct ShareCardView: View {
    let fromValue: String
    let fromUnit: String
    let toValue: String
    let toUnit: String
    let funFact: String?
    /// Shown when `funFact` is nil — e.g. `1 Meter = 0.001 Kilometer`.
    let formulaLine: String?
    var accent: Color

    var body: some View {
        ZStack {
            accent

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("measured with")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Measure Anything")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(fromValue) \(fromUnit)")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.7))
                    Text("=")
                        .font(.system(size: 42))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(toValue)
                        .font(.system(size: 72, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.4)
                        .lineLimit(1)
                    Text(toUnit)
                        .font(.system(size: 32))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                if let fact = funFact, !fact.isEmpty {
                    Text(fact)
                        .font(.system(size: 18))
                        .italic()
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let formulaLine, !formulaLine.isEmpty {
                    Text(formulaLine)
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(60)
        }
        .frame(width: 1080, height: 1080)
    }
}

extension ShareCardView {
    @MainActor
    static func renderImage(
        fromValue: String,
        fromUnit: String,
        toValue: String,
        toUnit: String,
        funFact: String?,
        formulaLine: String?,
        accent: Color
    ) -> UIImage? {
        if #available(iOS 16.0, *) {
            let view = ShareCardView(
                fromValue: fromValue,
                fromUnit: fromUnit,
                toValue: toValue,
                toUnit: toUnit,
                funFact: funFact,
                formulaLine: formulaLine,
                accent: accent
            )
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1.0
            return renderer.uiImage
        }
        return nil
    }
}
