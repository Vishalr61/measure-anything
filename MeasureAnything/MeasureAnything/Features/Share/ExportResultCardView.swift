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
                    .foregroundStyle(.quaternary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            prominentOutputText

            memeBlock(font: .subheadline)
        }
    }

    @ViewBuilder
    private var prominentOutputText: some View {
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
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: ConverterLayout.cardCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}
