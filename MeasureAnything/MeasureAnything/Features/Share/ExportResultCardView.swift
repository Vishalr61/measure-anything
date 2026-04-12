import SwiftUI

/// Inner conversion lines (shared by the converter and the image export).
struct ResultCardContent: View {
    let inputFormatted: String
    let fromName: String
    let outputFormatted: String
    let toName: String
    let meme: String?
    /// Larger type on the live converter; export keeps the default.
    var prominent: Bool = false
    /// Optional factor line (e.g. linear conversions); omitted for export.
    var equivalenceLine: String? = nil
    /// Live converter: subtle tint behind meme copy when present.
    var categoryAccent: Color? = nil
    /// When set (prominent layout), output shows large primary value + accent-colored symbol (e.g. `ft`).
    var outputUnitSymbol: String? = nil

    var body: some View {
        if prominent {
            prominentLayout
        } else {
            exportLayout
        }
    }

    private var exportLayout: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.tightSpacing) {
            Text("\(inputFormatted) \(fromName)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 2)

            Text("\(outputFormatted) \(toName)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .monospacedDigit()

            memeBlock(font: .callout)
        }
    }

    private var prominentLayout: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.rhythm12) {
            Text("\(inputFormatted) \(fromName)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.88)

            if let equivalenceLine, !equivalenceLine.isEmpty {
                Text(equivalenceLine)
                    .font(.caption2)
                    .foregroundStyle(
                        categoryAccent.map { $0.opacity(0.48) } ?? Color.secondary.opacity(0.55)
                    )
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            prominentOutputText

            prominentMemeBlock
        }
    }

    @ViewBuilder
    private var prominentOutputText: some View {
        if let sym = outputUnitSymbol, !sym.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    prominentOutputValueText(outputFormatted)
                    Text(sym)
                        .font(.title.weight(.bold))
                        .foregroundStyle(categoryAccent ?? .accentColor)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Text(toName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        } else {
            let text = Text("\(outputFormatted) \(toName)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
                .monospacedDigit()
                .minimumScaleFactor(0.45)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            if #available(iOS 17.0, *) {
                text.contentTransition(.numericText())
            } else {
                text
            }
        }
    }

    @ViewBuilder
    private func prominentOutputValueText(_ value: String) -> some View {
        let text = Text(value)
            .font(.largeTitle)
            .fontWeight(.bold)
            .foregroundStyle(.primary)
            .monospacedDigit()
            .minimumScaleFactor(0.45)
            .lineLimit(2)
            .multilineTextAlignment(.leading)

        if #available(iOS 17.0, *) {
            text.contentTransition(.numericText())
        } else {
            text
        }
    }

    @ViewBuilder
    private func memeBlock(font: Font) -> some View {
        if let meme, !meme.isEmpty {
            Divider()
                .padding(.vertical, ConverterLayout.rhythm8)
            Text(meme)
                .font(font)
                .foregroundStyle(.secondary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var prominentMemeBlock: some View {
        if let meme, !meme.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                    .padding(.vertical, ConverterLayout.rhythm8)
                Text(meme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(ConverterLayout.rhythm12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                    .fill((categoryAccent ?? .clear).opacity(categoryAccent != nil ? 0.11 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ConverterLayout.secondaryBlockCornerRadius, style: .continuous)
                    .strokeBorder(
                        (categoryAccent ?? .clear).opacity(categoryAccent != nil ? 0.22 : 0),
                        lineWidth: ConverterLayout.strokeHairline
                    )
            )
        }
    }
}

/// Full card with title + chrome for `ImageRenderer` export.
struct ExportResultCardView: View {
    let inputFormatted: String
    let fromName: String
    let outputFormatted: String
    let toName: String
    let meme: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.blockSpacing) {
            Text("Result")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            ResultCardContent(
                inputFormatted: inputFormatted,
                fromName: fromName,
                outputFormatted: outputFormatted,
                toName: toName,
                meme: meme
            )
        }
        .frame(maxWidth: 360, alignment: .leading)
        .padding(ConverterLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .fill(Color(hex: "#F0F0F3"))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(ConverterLayout.strokeOpacitySubtle), lineWidth: ConverterLayout.strokeHairline)
        )
    }
}
