import SwiftUI

struct AbsurdNudgeCard: View {
    let absurdResult: String
    let accent: Color
    let onTryAbsurd: () -> Void
    let onDismiss: () -> Void

    private var absurdModeBodyLine: AttributedString {
        let bodyColor = Color(hex: "#2C2C2A")
        var prefix = AttributedString("That's also ")
        prefix.font = .system(size: 13)
        prefix.foregroundColor = bodyColor

        var boldPart = AttributedString(absurdResult)
        boldPart.font = .system(size: 13, weight: .bold)
        boldPart.foregroundColor = bodyColor

        var suffix = AttributedString(" in Absurd mode.")
        suffix.font = .system(size: 13)
        suffix.foregroundColor = bodyColor

        prefix.append(boldPart)
        prefix.append(suffix)
        return prefix
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(accent)
                    Text("Did you know")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(accent)
                        .tracking(0.8)
                        .textCase(.uppercase)
                }
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                }
                .buttonStyle(.plain)
            }

            Text(absurdModeBodyLine)
                .foregroundStyle(Color(hex: "#2C2C2A"))

            Button(action: onTryAbsurd) {
                HStack(spacing: 4) {
                    Text("Try Absurd mode")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(accent)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color(hex: "#EAF5F4"))
        .cornerRadius(14)
    }
}
