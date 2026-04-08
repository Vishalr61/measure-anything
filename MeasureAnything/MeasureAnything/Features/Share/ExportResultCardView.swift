import SwiftUI

/// Inner conversion lines (shared by the converter and the image export).
struct ResultCardContent: View {
    let inputFormatted: String
    let fromName: String
    let outputFormatted: String
    let toName: String
    let meme: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(inputFormatted) \(fromName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
            Text("\(outputFormatted) \(toName)")
                .font(.title2.weight(.semibold))

            if let meme, !meme.isEmpty {
                Divider()
                Text(meme)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Result")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            ResultCardContent(
                inputFormatted: inputFormatted,
                fromName: fromName,
                outputFormatted: outputFormatted,
                toName: toName,
                meme: meme
            )
        }
        .frame(maxWidth: 360, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
