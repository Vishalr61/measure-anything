import SwiftUI
import UIKit
import MeasureAnythingCore

/// “To” card: baseline-aligned result + unit, formula, then Copy / Share / Save grid.
struct ToCard: View {
    let toUnitName: String
    /// Plain result string for accessibility and consistency with copy/paste text.
    let resultText: String
    /// Display string (superscript exponent when scientific).
    let resultAttributed: AttributedString
    /// Live equivalence (e.g. `50 Meter = 263.16 Kilometer`); `nil` skips formula row only.
    let formulaLine: String?
    /// Category accent for result, unit picker, and Save action (matches chips / swap / dice).
    let accent: Color
    let isSaved: Bool
    let copyEnabled: Bool
    let shareEnabled: Bool
    let saveEnabled: Bool
    let usesPlaceholderResult: Bool
    let onCopy: () -> Void
    let onShare: () -> Void
    let onSave: () -> Void
    @Binding var selectedToUnitID: UnitDefinition.ID
    let availableUnits: [UnitDefinition]
    /// Scale applied to the "To" unit pill during swap (driven by parent; default `1`).
    var unitPillScale: CGFloat = 1

    @AppStorage("hasSeenLongPressCopy") private var hasSeenLongPressCopy: Bool = false

    @State private var saveStarScale: CGFloat = 1.0
    @State private var showToPicker = false
    @State private var showCopiedConfirmation: Bool = false

    /// When the user hasn’t long-pressed yet, nudge discoverability (hidden forever after first long-press copy).
    private var showHoldToCopyHint: Bool {
        !hasSeenLongPressCopy && copyEnabled && !usesPlaceholderResult
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("To")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(Color(hex: "#888780"))
                .tracking(1.0)
                .textCase(.uppercase)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .lastTextBaseline) {
                    ZStack(alignment: .topTrailing) {
                        Text(resultAttributed)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(usesPlaceholderResult ? Color.secondary.opacity(0.55) : accent)
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .accessibilityLabel("Converted amount, \(resultText)")
                            .accessibilityHint(copyEnabled ? "Long press to copy the converted value" : "")
                            .onLongPressGesture(minimumDuration: 0.55) {
                                longPressCopyResult()
                            }

                        if showCopiedConfirmation {
                            Text("Copied")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color(.systemGray2))
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.92)))
                                .offset(x: 4, y: -6)
                                .accessibilityHidden(true)
                        }
                    }

                    Spacer()

                    UnitPickerPillButton(
                        name: toUnitName,
                        accent: accent,
                        style: .inline
                    ) {
                        showToPicker = true
                    }
                    .scaleEffect(unitPillScale, anchor: .center)
                    .sheet(isPresented: $showToPicker) {
                        UnitPickerSheet(
                            units: availableUnits,
                            selectedID: selectedToUnitID,
                            accent: accent
                        ) { newID in
                            selectedToUnitID = newID
                        }
                    }
                }

                if showHoldToCopyHint {
                    Text("Hold to copy")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                        .accessibilityHidden(true)
                }
            }
            .padding(.bottom, 8)

            if let formulaLine {
                Rectangle()
                    .fill(Color(hex: "#F5F5F7"))
                    .frame(height: 0.5)
                    .padding(.bottom, 6)

                Text(formulaLine)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(hex: "#888780"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 10)
            }

            Rectangle()
                .fill(Color(hex: "#F5F5F7"))
                .frame(height: 0.5)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                ActionButton(
                    icon: "doc.on.doc",
                    label: "Copy",
                    background: Color(hex: "#F0F0F3"),
                    foreground: Color(hex: "#5F5E5A"),
                    disabled: !copyEnabled,
                    action: {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        onCopy()
                    }
                )
                ActionButton(
                    icon: "square.and.arrow.up",
                    label: "Share",
                    background: Color(hex: "#F0F0F3"),
                    foreground: Color(hex: "#5F5E5A"),
                    disabled: !shareEnabled,
                    action: onShare
                )
                ActionButton(
                    icon: isSaved ? "star.fill" : "star",
                    label: isSaved ? "Saved" : "Save",
                    background: accent.opacity(0.10),
                    foreground: accent,
                    disabled: isSaved || !saveEnabled,
                    fadeWhenDisabled: !isSaved,
                    iconScale: saveStarScale,
                    action: {
                        guard saveEnabled, !isSaved else { return }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSave()
                    }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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
                    saveStarScale = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        saveStarScale = 1.0
                    }
                }
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.65)) {
                    saveStarScale = 1.12
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        saveStarScale = 1.0
                    }
                }
            }
        }
    }

    /// Same pasteboard + success haptic as the Copy action (`ConverterViewModel.copyResult`).
    private func longPressCopyResult() {
        guard copyEnabled else { return }
        onCopy()
        hasSeenLongPressCopy = true
        withAnimation(.easeInOut(duration: 0.15)) {
            showCopiedConfirmation = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopiedConfirmation = false
            }
        }
    }
}
