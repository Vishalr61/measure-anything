import SwiftUI

/// Shown once on first launch (after the brand animation) to orient new users.
/// Dismissed permanently via `AppStorage("hasSeenOnboarding")`.
struct OnboardingOverlayView: View {
    var onFinished: () -> Void

    private struct Step {
        let icon: String
        let title: String
        let body: String
    }

    private let steps: [Step] = [
        Step(
            icon: "square.grid.2x2",
            title: "Pick what to measure",
            body: "Swipe the category bar to switch between Length, Mass, Time, Volume, and Temperature."
        ),
        Step(
            icon: "arrow.left.arrow.right.circle",
            title: "Choose your units",
            body: "Tap either unit pill to open the picker — mix standard units with wild absurd ones freely."
        ),
        Step(
            icon: "dice",
            title: "Roll for surprises",
            body: "Tap Roll the Dice for a random weird conversion. Long-press briefly to randomise both units at once."
        ),
        Step(
            icon: "sparkles",
            title: "Explore everything",
            body: "Head to the Explore tab to search across every unit and uncover quirky fun facts."
        ),
    ]

    @State private var currentIndex: Int = 0
    @State private var cardOpacity: Double = 1
    @State private var cardOffsetY: CGFloat = 0

    private let accent = Color(red: 0x2B / 255, green: 0x5C / 255, blue: 0xE6 / 255)

    var body: some View {
        ZStack {
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 0) {
                Spacer()

                stepCard
                    .opacity(cardOpacity)
                    .offset(y: cardOffsetY)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 52)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var stepCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Progress dots
            HStack(spacing: 6) {
                ForEach(0 ..< steps.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentIndex ? accent : Color.white.opacity(0.3))
                        .frame(width: idx == currentIndex ? 20 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
                }
                Spacer()
                Button("Skip") { finish() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .accessibilityLabel("Skip tutorial")
            }
            .padding(.bottom, 24)

            // Icon
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 56, height: 56)
                Image(systemName: steps[currentIndex].icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 18)

            // Title
            Text(steps[currentIndex].title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x18 / 255))
                .padding(.bottom, 10)

            // Body
            Text(steps[currentIndex].body)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color(red: 0x55 / 255, green: 0x55 / 255, blue: 0x50 / 255))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 32)

            // Next / Done button
            Button(action: advance) {
                Text(currentIndex == steps.count - 1 ? "Get started" : "Next")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentIndex == steps.count - 1 ? "Get started" : "Next tip")
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
        )
    }

    private func advance() {
        if currentIndex < steps.count - 1 {
            animateToStep(currentIndex + 1)
        } else {
            finish()
        }
    }

    private func animateToStep(_ next: Int) {
        withAnimation(.easeIn(duration: 0.15)) {
            cardOpacity = 0
            cardOffsetY = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentIndex = next
            cardOffsetY = 12
            withAnimation(.easeOut(duration: 0.2)) {
                cardOpacity = 1
                cardOffsetY = 0
            }
        }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.3)) {
            cardOpacity = 0
            cardOffsetY = 20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onFinished()
        }
    }
}

#Preview {
    OnboardingOverlayView(onFinished: {})
}
