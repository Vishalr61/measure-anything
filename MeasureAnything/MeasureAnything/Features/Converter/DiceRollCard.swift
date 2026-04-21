import SwiftUI

struct DiceRollCard: View {
    @ObservedObject var vm: ConverterViewModel
    var accent: Color
    @State private var isPressed: Bool = false
    @State private var holdProgress: CGFloat = 0
    @State private var ringOpacity: Double = 0
    @State private var didCompleteLongPress: Bool = false
    @State private var longPressWorkItem: DispatchWorkItem?
    @State private var showHoldHint: Bool = false

    @State private var decorativeFace: Int = Int.random(in: 1...6)
    @State private var pipOpacity: Double = 1
    @State private var extraDieRotation: Double = 0
    @State private var patternPulseMultiplier: Double = 1

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            leftColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            rightColumn
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .highPriorityGesture(pressGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roll the dice")
        .accessibilityHint("Tap to randomise the target unit. Long press briefly to randomise both units.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Randomise both units")) {
            triggerDualRoll()
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Roll the\ndice")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Get a random weird conversion")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            subtitleRow
        }
    }

    private var subtitleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if vm.diceSubtitleIsDualFormat {
                    Text(vm.diceLandedUnitName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    HStack(spacing: 0) {
                        Text("landed on ")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.78))

                        Text(vm.diceLandedUnitName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if vm.showDiceSubtitle, showHoldHint {
                Text("Hold for full chaos")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .opacity(vm.showDiceSubtitle ? 1 : 0)
        .frame(minHeight: 14, alignment: .leading)
        .animation(.easeIn(duration: 0.25), value: vm.showDiceSubtitle)
    }

    private var rightColumn: some View {
        ZStack {
            ring
            DiceFaceView(face: $decorativeFace, faceColor: accent, pipOpacity: pipOpacity)
                .rotationEffect(.degrees(vm.diceRotationDegrees + extraDieRotation))
        }
    }

    private var cardBackground: some View {
        ZStack(alignment: .topTrailing) {
            accent

            Circle()
                .stroke(Color.white.opacity(0.1 * patternPulseMultiplier), lineWidth: 14)
                .frame(width: 90, height: 90)
                .offset(x: 30, y: -30)
        }
    }

    private var ring: some View {
        Circle()
            .trim(from: 0, to: holdProgress)
            .stroke(Color.white.opacity(0.60), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 54, height: 54)
            .opacity(ringOpacity)
            .allowsHitTesting(false)
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isPressed {
                    beginPress()
                }
            }
            .onEnded { _ in
                endPress()
            }
    }

    private func beginPress() {
        isPressed = true
        didCompleteLongPress = false

        ringOpacity = 1
        holdProgress = 0
        withAnimation(.linear(duration: 0.5)) {
            holdProgress = 1
        }

        longPressWorkItem?.cancel()
        let work = DispatchWorkItem {
            didCompleteLongPress = true
            completeLongPress()
        }
        longPressWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func endPress() {
        isPressed = false
        longPressWorkItem?.cancel()
        longPressWorkItem = nil

        if didCompleteLongPress {
            resetRing(animated: true)
            return
        }

        resetRing(animated: true)
        triggerSingleRoll()
    }

    private func completeLongPress() {
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()

        withAnimation(.easeInOut(duration: 0.12)) {
            ringOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.18)) {
                ringOpacity = 0
            }
        }

        vm.setHasUsedLongPressRoll()
        showHoldHint = false

        triggerDualRoll()
    }

    private func resetRing(animated: Bool) {
        let apply = {
            self.holdProgress = 0
            self.ringOpacity = 0
        }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                apply()
            }
        } else {
            apply()
        }
    }

    private func triggerSingleRoll() {
        animateDecorativeRoll()
        pulsePattern()
        vm.rollDice()
        scheduleHoldHintAfterSingleRollIfNeeded()
    }

    private func triggerDualRoll() {
        animateDecorativeRoll()
        pulsePattern()
        vm.rollDiceDual()
    }

    private func animateDecorativeRoll() {
        withAnimation(.easeOut(duration: 0.15)) {
            pipOpacity = 0
        }

        let nextFace = Int.random(in: 1...6)
        let offset = Double.random(in: 15...45) * (Bool.random() ? 1 : -1)
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 120, damping: 14, initialVelocity: 8)) {
            extraDieRotation = offset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            decorativeFace = nextFace
            withAnimation(.easeIn(duration: 0.15)) {
                pipOpacity = 1
            }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 90, damping: 12, initialVelocity: 6)) {
                extraDieRotation = 0
            }
        }
    }

    private func pulsePattern() {
        withAnimation(.easeIn(duration: 0.15)) {
            patternPulseMultiplier = 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.4)) {
                patternPulseMultiplier = 1
            }
        }
    }

    private func scheduleHoldHintAfterSingleRollIfNeeded() {
        guard vm.shouldShowLongPressDiscoverabilityHint else { return }
        showHoldHint = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard vm.shouldShowLongPressDiscoverabilityHint else { return }
            withAnimation(.easeIn(duration: 0.3)) {
                showHoldHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showHoldHint = false
                }
            }
        }
    }
}

