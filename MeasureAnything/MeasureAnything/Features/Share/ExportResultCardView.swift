import SwiftUI

/// Inner conversion lines (shared by the converter and the image export).
struct ResultCardContent: View {
    let inputFormatted: String
    let fromName: String
    let outputFormatted: String
    let toName: String
    let meme: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ConverterLayout.tightSpacing) {
            Text("\(inputFormatted) \(fromName)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Image(systemName: "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.vertical, 2)

            Text("\(outputFormatted) \(toName)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()

            if let meme, !meme.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text(meme)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .italic()
                    .fixedSize(horizontal: false, vertical: true)
            }
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
