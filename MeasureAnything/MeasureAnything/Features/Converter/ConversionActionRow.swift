import SwiftUI
import UIKit

/// Share + Save as compact circle actions below the TO row.
struct ConversionActionRow: View {
    let onShare: () -> Void
    let onSave: () -> Void
    let isSaved: Bool
    let shareEnabled: Bool
    let saveEnabled: Bool

    private static let shareIconGray = Color(red: 0x5F / 255, green: 0x5E / 255, blue: 0x5A / 255)
    private static let borderGray = Color(red: 0xE0 / 255, green: 0xE0 / 255, blue: 0xE0 / 255)
    private static let saveFill = Color(red: 0xEB / 255, green: 0xF3 / 255, blue: 0xFD / 255)
    private static let saveStroke = Color(red: 0xC8 / 255, green: 0xD9 / 255, blue: 0xFF / 255)
    private static let saveBlue = Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)

    var body: some View {
        HStack(spacing: 24) {
            Button {
                guard shareEnabled else { return }
                onShare()
            } label: {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(Self.borderGray, lineWidth: 0.5)
                        )
                        .overlay(
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundStyle(Self.shareIconGray)
                        )
                    Text("Share")
                        .font(.system(size: 11))
                        .foregroundStyle(Self.shareIconGray)
                }
            }
            .buttonStyle(.plain)
            .opacity(shareEnabled ? 1 : 0.4)
            .accessibilityLabel("Share")

            Button {
                guard saveEnabled, !isSaved else { return }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onSave()
            } label: {
                VStack(spacing: 4) {
                    Circle()
                        .fill(Self.saveFill)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Circle()
                                .stroke(Self.saveStroke, lineWidth: 0.5)
                        )
                        .overlay(
                            Image(systemName: isSaved ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(Self.saveBlue)
                                .scaleEffect(isSaved ? 1.15 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSaved)
                        )
                    Text(isSaved ? "Saved" : "Save")
                        .font(.system(size: 11))
                        .foregroundStyle(Self.saveBlue)
                }
            }
            .buttonStyle(.plain)
            .disabled(isSaved || !saveEnabled)
            .opacity((isSaved || saveEnabled) ? 1 : 0.4)
            .accessibilityLabel(isSaved ? "Already saved as favorite" : "Save as favorite")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}
