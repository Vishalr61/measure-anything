import SwiftUI

/// Truncated fun-fact line on Explore unit rows: category accent (muted) + full-opacity trailing arrow.
struct FactCardRowAffordance: View {
    let text: String
    let accent: Color

    var body: some View {
        (Text(text).foregroundStyle(accent.opacity(0.82))
            + Text(" →").foregroundStyle(accent))
            .font(.system(size: 12))
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Fact: \(text)")
            .accessibilityHint("Opens full fact card")
    }
}
