import SwiftUI

/// Shared keyboard accessory content styled to blend with the system decimal keypad.
struct KeyboardAccessoryBar: View {
    let accent: Color
    let onCancel: () -> Void
    let onDone: () -> Void

    private var barBackground: Color {
        Color(uiColor: .systemGray5)
    }

    private var topDivider: Color {
        Color(uiColor: .separator).opacity(0.35)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button("Cancel", action: onCancel)
                .font(.body)
                .foregroundStyle(accent.opacity(0.72))

            Spacer(minLength: 12)

            Button("Done", action: onDone)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            UnevenRoundedRectangle(
                topLeadingRadius: 18,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18,
                style: .continuous
            )
            .fill(barBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(topDivider)
                    .frame(height: 0.5)
            }
        }
        .padding(.horizontal, 6)
        .shadow(color: Color.black.opacity(0.03), radius: 1, y: -0.5)
    }
}
