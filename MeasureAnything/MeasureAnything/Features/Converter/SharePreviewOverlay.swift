import SwiftUI

/// In-app preview shown above HomeView when the user taps SHARE.
/// Renders a scaled-down `ShareCardView` plus Share / Save actions.
/// Not a sheet — added to the root ZStack so iOS share sheet can layer
/// on top once dismissed.
struct SharePreviewOverlay: View {
    let fromValue: String
    let fromUnit: String
    let toValue: String
    let toUnit: String
    let category: String
    let isPrecisionMode: Bool
    let accentColor: Color
    var onDismiss: () -> Void
    var onShare: () -> Void
    var onSave: () -> Void

    private let previewScale: CGFloat = 0.72

    var body: some View {
        ZStack {
            // Blur scrim with darker tint behind it
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .background(Color.black.opacity(0.45).ignoresSafeArea())
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 16)

                // Card preview (scaled, frame collapsed to scaled height)
                ShareCardView(
                    fromValue: fromValue,
                    fromUnit: fromUnit,
                    toValue: toValue,
                    toUnit: toUnit,
                    category: category,
                    isPrecisionMode: isPrecisionMode
                )
                .frame(width: ShareCardView.cardWidth, height: ShareCardView.cardHeight)
                .scaleEffect(previewScale)
                .frame(
                    width: ShareCardView.cardWidth * previewScale,
                    height: ShareCardView.cardHeight * previewScale
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.6), radius: 32, y: 16)

                Spacer(minLength: 20)

                actionButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: — Subviews

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close share preview")

            Spacer()

            Text("Share your conversion")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))

            Spacer()

            // Balance spacer — same dimensions as the close button
            Color.clear.frame(width: 30, height: 30)
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button(action: onShare) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Share image")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor)
                )
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                Text("Save to Photos")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}
