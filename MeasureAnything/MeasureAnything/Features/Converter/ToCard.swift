import SwiftUI
import UIKit
import MeasureAnythingCore

/// Expanded “To” conversion card: header actions, baseline-aligned number + unit row, formula footnote.
struct ToCard: View {
    let toUnitName: String
    let resultText: String
    /// Live equivalence line (e.g. `50 Meter = 263.16 Pencil`); `nil` hides row 3.
    let formulaLine: String?
    /// Category accent (teal family) — used where specs reference “brand teal”.
    let accent: Color
    let isSaved: Bool
    let shareEnabled: Bool
    let saveEnabled: Bool
    let usesPlaceholderResult: Bool
    let onShare: () -> Void
    let onSave: () -> Void
    @Binding var selectedToUnitID: UnitDefinition.ID
    let availableUnits: [UnitDefinition]

    @State private var starVisualScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1 — label + Share / Save
            HStack(alignment: .center) {
                Text("To")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Color(hex: "#888780"))
                    .tracking(1.0)
                    .textCase(.uppercase)

                Spacer()

                HStack(spacing: 5) {
                    Button {
                        guard shareEnabled else { return }
                        onShare()
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#F5F5F7"))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(hex: "#5F5E5A"))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!shareEnabled)
                    .opacity(shareEnabled ? 1 : 0.4)
                    .accessibilityLabel("Share")

                    Button {
                        guard saveEnabled, !isSaved else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSave()
                    } label: {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(hex: "#EAF5F4"))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Image(systemName: isSaved ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundStyle(accent)
                                    .scaleEffect(starVisualScale)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaved || !saveEnabled)
                    .opacity((isSaved || saveEnabled) ? 1 : 0.4)
                    .accessibilityLabel(isSaved ? "Already saved as favorite" : "Save as favorite")
                }
            }
            .padding(.bottom, 8)

            // Row 2 — hero number + unit picker (same baseline as FROM amount + pill)
            HStack(alignment: .lastTextBaseline) {
                Text(resultText)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(usesPlaceholderResult ? Color.secondary.opacity(0.55) : accent)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .textSelection(.enabled)
                    .accessibilityLabel("Converted amount, \(resultText)")

                Spacer()

                Picker(selection: $selectedToUnitID) {
                    ForEach(availableUnits, id: \.id) { u in
                        Text(u.name).tag(u.id)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(toUnitName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .pickerStyle(.menu)
                .tint(accent)
            }
            .padding(.bottom, 8)

            // Row 3 — hairline + live formula
            if let formulaLine {
                Rectangle()
                    .fill(Color(hex: "#F5F5F7"))
                    .frame(height: 0.5)
                    .padding(.bottom, 6)

                Text(formulaLine)
                    .font(.system(size: 9))
                    .foregroundStyle(Color(hex: "#888780"))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(hex: "#EBEBEB"), lineWidth: 0.5)
        )
        .onChange(of: isSaved) { _, new in
            if new {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    starVisualScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        starVisualScale = 1.0
                    }
                }
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    starVisualScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        starVisualScale = 1.0
                    }
                }
            }
        }
    }
}
