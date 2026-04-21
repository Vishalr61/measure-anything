import SwiftUI
import MeasureAnythingCore

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
    @State private var cardLandingScale: Double = 1

    @State private var pendingResultTransitionOut: Bool = false
    @State private var resultOpacity: Double = 1
    @State private var resultOffsetY: CGFloat = 0

    @State private var lastRollKind: RollKind = .single
    @State private var toShakeOffsetX: CGFloat = 0
    @State private var fromPulseScale: Double = 1
    @State private var toPulseScale: Double = 1
    @State private var restingRandomTilt: Double = 0
    @State private var idleBreathOn: Bool = false

    private enum RollKind {
        case single
        case dual
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            leftColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            dieHero
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .clipped()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(innerBorder)
        .scaleEffect((isPressed ? 0.92 : 1.0) * cardLandingScale)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .animation(.spring(response: 0.22, dampingFraction: 0.55), value: cardLandingScale)
        .highPriorityGesture(pressGesture)
        .onChange(of: vm.diceLandedUnitName) { _, newValue in
            guard !newValue.isEmpty else { return }
            animateResultTransitionIn()
            scheduleRestingTiltRandomize()
            switch lastRollKind {
            case .single:
                shakeToPill()
            case .dual:
                pulseBothUnits()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Roll the dice")
        .accessibilityHint("Tap to randomise the target unit. Long press briefly to randomise both units.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: Text("Randomise both units")) {
            triggerDualRoll()
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Roll the dice")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Get a random weird conversion")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

            subtitleRow
                .padding(.top, 4)
        }
    }

    private var subtitleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            resultBadge

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

    private var dieHero: some View {
        ZStack {
            ring
            dieContainer
                .rotationEffect(.degrees(vm.diceRotationDegrees + restingRandomTilt + extraDieRotation))
        }
    }

    private var cardBackground: some View {
        ZStack {
            accent

            CategoryTilePattern(
                category: vm.selectedCategory,
                color: .white,
                patternOpacity: 0.14 * patternPulseMultiplier
            )
            .overlay(patternSpotlightFade)
        }
    }

    private var patternSpotlightFade: some View {
        RadialGradient(
            colors: [
                accent.opacity(0.0),
                accent.opacity(0.60)
            ],
            center: UnitPoint(x: 0.82, y: 0.50),
            startRadius: 18,
            endRadius: 240
        )
    }

    private var innerBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            .padding(0.5)
            .allowsHitTesting(false)
    }

    private var dieContainer: some View {
        let isResting = !isPressed && !vm.isDiceRolling
        let breathScale: Double = idleBreathOn ? 1.02 : 1.0
        let baseFaceOpacity: Double = 0.22
        let faceOpacity: Double = isResting ? (baseFaceOpacity + (idleBreathOn ? 0.03 : 0)) : baseFaceOpacity

        return DiceFaceView(
            face: $decorativeFace,
            faceColor: Color.white.opacity(faceOpacity),
            pipOpacity: pipOpacity,
            size: 56
        )
        .overlay(bevelOverlay)
        .shadow(color: .black.opacity(0.25), radius: 4, x: 2, y: 3)
        .scaleEffect(isResting ? breathScale : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                idleBreathOn = true
            }
        }
    }

    private var bevelOverlay: some View {
        RoundedRectangle(cornerRadius: 56 * 0.20, style: .continuous)
            .fill(.clear)
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.08), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 56 * 0.20, style: .continuous))
            )
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.05), .clear],
                    startPoint: .bottomTrailing,
                    endPoint: .topLeading
                )
                .clipShape(RoundedRectangle(cornerRadius: 56 * 0.20, style: .continuous))
            )
            .allowsHitTesting(false)
    }

    private var ring: some View {
        Circle()
            .trim(from: 0, to: holdProgress)
            .stroke(Color.white.opacity(0.60), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 64, height: 64)
            .opacity(ringOpacity)
            .allowsHitTesting(false)
    }

    private var resultBadge: some View {
        HStack(spacing: 8) {
            Text(fromName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .scaleEffect(fromPulseScale)

            Text(lastRollKind == .dual ? "⇄" : "→")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))

            Text(toName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .scaleEffect(toPulseScale)
                .offset(x: toShakeOffsetX)
        }
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(resultOpacity)
        .offset(y: resultOffsetY)
        .animation(.easeInOut(duration: 0.15), value: resultOpacity)
        .animation(.easeInOut(duration: 0.15), value: resultOffsetY)
    }

    private var fromName: String {
        vm.fromUnit?.name ?? "—"
    }

    private var toName: String {
        vm.toUnit?.name ?? "—"
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
        idleBreathOn = false

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let secondary = UIImpactFeedbackGenerator(style: .light)
            secondary.impactOccurred()
        }

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
        lastRollKind = .single
        animateResultTransitionOut()
        animateDecorativeRollSingle()
        pulsePattern(multiplier: 2, settle: 0.4)
        vm.rollDice()
        scheduleHoldHintAfterSingleRollIfNeeded()
    }

    private func triggerDualRoll() {
        lastRollKind = .dual
        animateResultTransitionOut()
        animateDecorativeRollDual()
        pulsePattern(multiplier: 3, settle: 0.6)
        vm.rollDiceDual()
        scheduleDualLandingBounce()
    }

    private func animateDecorativeRollSingle() {
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

    private func animateDecorativeRollDual() {
        let nextFace = Int.random(in: 1...6)
        withAnimation(.linear(duration: 0.5)) {
            extraDieRotation = 720 * (Bool.random() ? 1 : -1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            decorativeFace = nextFace
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 90, damping: 14, initialVelocity: 6)) {
                extraDieRotation = 0
            }
        }
    }

    private func pulsePattern(multiplier: Double, settle: Double) {
        withAnimation(.easeIn(duration: 0.15)) {
            patternPulseMultiplier = multiplier
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: settle)) {
                patternPulseMultiplier = 1
            }
        }
    }

    private func animateResultTransitionOut() {
        pendingResultTransitionOut = true
        withAnimation(.easeOut(duration: 0.15)) {
            resultOpacity = 0
            resultOffsetY = -4
        }
    }

    private func animateResultTransitionIn() {
        guard pendingResultTransitionOut else { return }
        pendingResultTransitionOut = false
        resultOpacity = 0
        resultOffsetY = 4
        withAnimation(.easeIn(duration: 0.15)) {
            resultOpacity = 1
            resultOffsetY = 0
        }
    }

    private func shakeToPill() {
        let steps: [CGFloat] = [0, 3, -3, 2, -1, 0]
        for (idx, x) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.06) {
                withAnimation(.linear(duration: 0.06)) {
                    toShakeOffsetX = x
                }
            }
        }
    }

    private func pulseBothUnits() {
        withAnimation(.interpolatingSpring(mass: 1, stiffness: 160, damping: 14, initialVelocity: 8)) {
            fromPulseScale = 1.08
            toPulseScale = 1.08
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 140, damping: 16, initialVelocity: 6)) {
                fromPulseScale = 1
                toPulseScale = 1
            }
        }
    }

    private func scheduleDualLandingBounce() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.1)) {
                cardLandingScale = 1.02
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeIn(duration: 0.1)) {
                    cardLandingScale = 1.0
                }
            }
        }
    }

    private func scheduleRestingTiltRandomize() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.22)) {
                restingRandomTilt = Double.random(in: -8...8)
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

