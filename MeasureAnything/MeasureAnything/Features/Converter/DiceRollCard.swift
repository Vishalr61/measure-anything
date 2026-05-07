import Combine
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
    @State private var hasRolledOnce: Bool = false
    @State private var hasUsedShake: Bool = false

    @State private var decorativeFace: Int = Int.random(in: 1...6)
    @State private var pipOpacity: Double = 1
    @State private var extraDieRotation: Double = 0
    @State private var patternPulseMultiplier: Double = 1
    @State private var cardLandingScale: Double = 1

    @State private var pendingResultTransitionOut: Bool = false
    @State private var resultOpacity: Double = 1
    @State private var resultOffsetY: CGFloat = 0
    /// Independent opacity/offset for the TO half of the badge so a
    /// normal single tap can fade only TO (FROM never changes on single).
    @State private var resultToOpacity: Double = 1.0
    @State private var resultToOffsetY: CGFloat = 0

    @State private var lastRollKind: RollKind = .single
    @State private var toShakeOffsetX: CGFloat = 0
    @State private var fromPulseScale: Double = 1
    @State private var toPulseScale: Double = 1
    @State private var restingRandomTilt: Double = 0
    @State private var restingTiltX: Double = 0
    @State private var restingTiltY: Double = 0
    @State private var idleBreathOn: Bool = false

    // MARK: – Chaos mode
    @State private var swipeInProgress: Bool = false
    @State private var swipeDragOffset: CGFloat = 0
    @State private var swipeThresholdReached: Bool = false
    @State private var chaosBledAmount: Double = 0
    @State private var hasTickedThisSwipe: Bool = false
    @State private var resultLandingScale: Double = 1.0
    @State private var slotMachineText: String = ""
    @State private var isSlotMachineRunning: Bool = false
    @State private var slotTextOpacity: Double = 0
    @State private var slotTextOffsetY: CGFloat = 0

    private enum RollKind {
        case single
        case dual
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                leftColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(1)

                dieHero
                    .layoutPriority(0)
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
            .offset(x: swipeDragOffset)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: cardLandingScale)
            .gesture(unifiedGesture)
            .onAppear {
                chaosBledAmount = vm.isChaosMode ? 1.0 : 0.0
            }
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
            .onChange(of: vm.shakeSingleRollRequest) { _, new in
                guard new > 0 else { return }
                hasRolledOnce = true
                hasUsedShake = true
                triggerSingleRoll()
            }
            .onChange(of: vm.shakeDualRollRequest) { _, new in
                guard new > 0 else { return }
                hasRolledOnce = true
                hasUsedShake = true
                triggerDualRoll()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Roll the dice")
            .accessibilityHint(vm.isChaosMode
                ? "Chaos mode active. Tap to roll any unit from any category. Swipe left to exit chaos."
                : "Tap to randomise the target unit. Long press to randomise both. Swipe right for chaos mode.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: Text("Randomise both units")) {
                triggerDualRoll()
            }

            chaosDots
        }
    }

    /// State-driven discoverability hint. One thing at a time, advances as
    /// the user demonstrates each gesture. Chaos mode overrides everything.
    private var hintText: String {
        if vm.isChaosMode {
            return "The universe decides."
        }
        if !hasRolledOnce {
            return "Tap to roll"
        }
        if vm.shouldShowLongPressDiscoverabilityHint {
            return "Long press for full random"
        }
        if !hasUsedShake {
            return "Shake to roll"
        }
        return "Tap · Long press · Shake"
    }

    /// Pip tint used to recolour the dice face's white pips in chaos mode.
    private var pipColor: Color {
        vm.isChaosMode ? Color(hex: "#C4B5FD") : .white
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Roll the dice")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)

                if vm.isChaosMode || swipeThresholdReached {
                    Text("CHAOS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#C4B5FD"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(hex: "#8B5CF6").opacity(0.25))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            Color(hex: "#8B5CF6").opacity(0.45),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                        .transition(
                            .opacity
                                .combined(with: .scale(scale: 0.6, anchor: .leading))
                                .combined(with: .offset(x: -8))
                        )
                }
            }
            .animation(
                .interpolatingSpring(mass: 0.6, stiffness: 220,
                                     damping: 12, initialVelocity: 8),
                value: vm.isChaosMode
            )
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7),
                value: swipeThresholdReached
            )

            rollHintLine

            // Slot machine renders independently of vm.showDiceSubtitle so
            // its prelude is actually visible (subtitleRow's opacity gate
            // would otherwise hide it). Crossfaded with subtitleRow so the
            // handoff is smooth instead of a hard snap.
            Group {
                if isSlotMachineRunning {
                    slotMachineRow
                        .padding(.top, 4)
                } else {
                    subtitleRow
                        .padding(.top, 4)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isSlotMachineRunning)
        }
    }

    /// Live pair badge mirroring the FROM/TO cycle during a roll.
    /// Falls back to the real unit names when the slot-machine override
    /// is nil so the badge has correct content the moment a roll starts
    /// (e.g. normal single tap leaves `slotMachineFromName` nil — the
    /// badge then shows the actual FROM with TO cycling).
    /// Tint switches to chaos light-purple in chaos mode.
    private var slotMachineRow: some View {
        let textColor: Color = vm.isChaosMode
            ? Color(hex: "#C4B5FD").opacity(0.9)
            : Color.white.opacity(0.9)

        return HStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(vm.slotMachineFromName ?? fromName)
                    .font(.system(size: 11, weight: .semibold,
                                  design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .padding(.leading, 10)
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.12),
                               value: vm.slotMachineFromName)

                Text(" → ")
                    .font(.system(size: 11, weight: .regular,
                                  design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.3))
                    .padding(.vertical, 4)

                Text(vm.slotMachineToName ?? toName)
                    .font(.system(size: 11, weight: .semibold,
                                  design: .rounded))
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .padding(.trailing, 10)
                    .padding(.vertical, 4)
                    .animation(.easeInOut(duration: 0.12),
                               value: vm.slotMachineToName)
            }
            .background(
                Color.white.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 8,
                                     style: .continuous)
            )

            Spacer(minLength: 0)
        }
        .frame(minHeight: 26, alignment: .leading)
    }

    private var rollHintLine: some View {
        Text(hintText)
            .font(.system(size: 12, weight: .regular, design: .rounded))
            .foregroundStyle(
                vm.isChaosMode
                    ? Color(hex: "#C4B5FD").opacity(0.8)
                    : Color.white.opacity(0.78)
            )
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
            .animation(.easeInOut(duration: 0.4), value: hintText)
    }

    private var subtitleRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            resultBadge
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
                .rotation3DEffect(
                    .degrees(restingTiltX),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.3
                )
                .rotation3DEffect(
                    .degrees(restingTiltY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.3
                )
        }
    }

    private var cardBackground: some View {
        ZStack {
            // Base colour cross-fade: accent <-> chaos dark, driven by
            // chaosBledAmount (0 = full accent, 1 = full chaos dark).
            // During a swipe this rides the finger so the colour visibly
            // bleeds across before the threshold tick.
            accent.opacity(1.0 - chaosBledAmount)
            Color(hex: "#0D0D1A").opacity(chaosBledAmount)

            CategoryTilePattern(
                category: vm.selectedCategory,
                color: .white,
                patternOpacity: (vm.isChaosMode ? 0.06 : 0.14)
                    * patternPulseMultiplier
            )
            .overlay(patternSpotlightFade)
        }
        .animation(.easeInOut(duration: 0.4), value: vm.isChaosMode)
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
            .strokeBorder(
                vm.isChaosMode
                    ? Color(hex: "#8B5CF6").opacity(0.3)
                    : Color.white.opacity(0.10),
                lineWidth: 0.5
            )
            .padding(0.5)
            .allowsHitTesting(false)
    }

    private var dieContainer: some View {
        let isResting = !isPressed && !vm.isDiceRolling
        let breathScale: Double = idleBreathOn ? 1.02 : 1.0
        let baseFaceOpacity: Double = 0.22
        let faceOpacity: Double = isResting ? (baseFaceOpacity + (idleBreathOn ? 0.03 : 0)) : baseFaceOpacity

        // DiceFaceView paints pips in white. `.colorMultiply(pipColor)` tints
        // them (and the face) with the chaos light-purple in chaos mode.
        return DiceFaceView(
            face: $decorativeFace,
            faceColor: vm.isChaosMode
                ? Color(hex: "#8B5CF6").opacity(0.3)
                : Color.white.opacity(faceOpacity),
            pipOpacity: pipOpacity,
            size: 56
        )
        .colorMultiply(pipColor)
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
        HStack(spacing: 0) {
            if vm.isChaosMode, vm.showDiceSubtitle {
                // Parsed chaos format: "CAT·fromName⇄toName"
                let parts = vm.diceLandedUnitName.components(separatedBy: "·")
                let categoryPrefix = parts.count >= 2 ? parts[0] : ""
                let pairPart = parts.count >= 2 ? parts[1] : vm.diceLandedUnitName

                HStack(spacing: 0) {
                    if !categoryPrefix.isEmpty {
                        Text(categoryPrefix)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#C4B5FD"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                        Rectangle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 0.5)
                            .padding(.vertical, 4)
                    }

                    Text(pairPart)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .background(
                    Color.white.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .opacity(resultOpacity)
                .offset(y: resultOffsetY)
                .scaleEffect(resultLandingScale, anchor: .leading)
                .animation(.easeInOut(duration: 0.15), value: resultOpacity)
                .animation(.easeInOut(duration: 0.15), value: resultOffsetY)

            } else {
                // Normal mode badge — split layout so FROM and TO can
                // transition independently. On a single tap FROM stays
                // visible while TO fades + slides; on a dual roll both
                // halves share `resultOpacity` / `resultOffsetY` for the
                // existing full-fade behaviour.
                HStack(spacing: 0) {
                    Text(fromName)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .opacity(lastRollKind == .single ? 1.0 : resultOpacity)

                    Text(lastRollKind == .dual ? " ⇄ " : " → ")
                        .font(.system(size: 11, weight: .regular, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .opacity(lastRollKind == .single ? 1.0 : resultOpacity)

                    // TO half — split into "live during slot machine"
                    // (always visible, mirrors cycling name) vs "post-roll"
                    // (uses resultToOpacity / Y so the fade-in lands cleanly).
                    // The else branch falls back to vm.slotMachineToName ??
                    // toName so the brief window between slot-end (1.30s)
                    // and real-value-land (1.40s) keeps showing the last
                    // cycled name — never the previous unit's stale name.
                    Group {
                        if isSlotMachineRunning && lastRollKind == .single {
                            Text(vm.slotMachineToName ?? toName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .id(vm.slotMachineToName ?? toName)
                                .contentTransition(.opacity)
                                .opacity(1.0)
                                .animation(.easeInOut(duration: 0.12),
                                           value: vm.slotMachineToName)
                        } else {
                            Text(vm.slotMachineToName ?? toName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .id(vm.slotMachineToName ?? toName)
                                .contentTransition(.opacity)
                                .opacity(lastRollKind == .single
                                    ? resultToOpacity
                                    : resultOpacity)
                                .offset(y: lastRollKind == .single
                                    ? resultToOffsetY
                                    : resultOffsetY)
                                .animation(.easeInOut(duration: 0.2),
                                           value: vm.slotMachineToName ?? toName)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                // Pill itself stays opaque — only contents animate.
                .scaleEffect(lastRollKind == .dual ? resultLandingScale : 1.0,
                             anchor: .leading)
                .scaleEffect(lastRollKind == .dual ? fromPulseScale : 1)
                .offset(x: lastRollKind == .single ? toShakeOffsetX : 0)
                .animation(.easeInOut(duration: 0.12), value: resultToOpacity)
                .animation(.easeInOut(duration: 0.12), value: resultToOffsetY)
                .animation(.easeInOut(duration: 0.15), value: resultOpacity)
                .animation(.easeInOut(duration: 0.15), value: resultOffsetY)
            }

            Spacer(minLength: 0)
        }
    }

    private var fromName: String {
        vm.fromUnit?.name ?? "—"
    }

    private var toName: String {
        vm.toUnit?.name ?? "—"
    }

    // MARK: – Chaos slot machine prelude

    /// Drives the slot-machine prelude during a chaos roll. Names cycle
    /// in the real FROM and TO pills via `vm.slotMachineFromName` and
    /// `vm.slotMachineToName` so the user sees the converter "searching"
    /// for a unit pair. No category-chip cycling — only FROM and TO.
    private func runSlotMachine() {
        guard vm.isChaosMode else { return }
        isSlotMachineRunning = true

        let allNames: [String] = UnitCategory.allCases.flatMap { cat in
            vm.exploreUnitDefinitions(for: cat)
                .filter { $0.kind == .absurd }
                .map { $0.name }
        }.shuffled()

        guard allNames.count >= 4 else {
            isSlotMachineRunning = false
            return
        }

        // Each name visible 0.25s, vertical slide 0.12s → 0.37s per cycle.
        // 4 cycles FROM (start 0.0s) end at 1.48s.
        // 4 cycles TO (offset 0.18s)  end at 1.66s.
        // rollDiceChaos lands at 2.0s → ~0.34s clean gap.
        let cycleDuration: Double = 0.37
        let totalCycles = 4

        // FROM lane
        for i in 0..<totalCycles {
            let cycleStart = Double(i) * cycleDuration
            let name = allNames[i % allNames.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + cycleStart) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    vm.slotMachineFromName = name
                }
            }
        }

        // TO lane — offset by 0.18s so FROM and TO never tick in lockstep,
        // drawn from the second slice so the same name never appears in
        // both pills simultaneously.
        for i in 0..<totalCycles {
            let cycleStart = 0.18 + Double(i) * cycleDuration
            let name = allNames[(i + totalCycles) % allNames.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + cycleStart) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    vm.slotMachineToName = name
                }
            }
        }

        // End the running flag — the override values stay set until
        // `rollDiceChaos()` clears them atomically with the real result.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.70) {
            isSlotMachineRunning = false
        }
    }

    /// Slot-machine prelude for a normal single tap (TO-only). Pulls
    /// names from the *current* category's absurd pool; FROM stays
    /// untouched. Decelerating schedule mirrors a physical reel
    /// slowing into rest. Aligns with `rollDice`'s 1.4s landing.
    private func runSlotMachineNormalSingle() {
        let pool: [String] = vm.exploreUnitDefinitions(for: vm.selectedCategory)
            .filter { $0.kind == .absurd }
            .map { $0.name }
            .shuffled()

        guard pool.count >= 2 else { return }
        isSlotMachineRunning = true

        // Decelerating schedule — names slow as they approach landing.
        // Gaps: 0.18 / 0.18 / 0.22 / 0.24 / 0.26 — last name lingers
        // ~0.32s before rollDice lands at 1.40s.
        let schedule: [Double] = [
            0.00,   // name 1 — fast
            0.18,   // name 2
            0.36,   // name 3
            0.58,   // name 4 — starts slowing
            0.82,   // name 5
            1.08    // name 6 — slow, near stop
        ]

        for (i, startTime) in schedule.enumerated() {
            let name = pool[i % pool.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + startTime) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    vm.slotMachineToName = name
                }
            }
        }

        // End slot machine — last name stays visible until
        // rollDice() lands at 1.40s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.30) {
            isSlotMachineRunning = false
        }
    }

    /// Slot-machine prelude for a normal dual roll (long press / shake).
    /// Both FROM and TO cycle on independent decelerating schedules
    /// (TO offset 0.12s for an asynchronous feel). Drawn from the
    /// current category's absurd pool. Aligns with `rollDiceDual`'s
    /// 1.6s landing.
    private func runSlotMachineNormalDual() {
        let pool: [String] = vm.exploreUnitDefinitions(for: vm.selectedCategory)
            .filter { $0.kind == .absurd }
            .map { $0.name }
            .shuffled()

        guard pool.count >= 4 else { return }
        isSlotMachineRunning = true

        // FROM schedule — starts immediately, decelerates into rest.
        let fromSchedule: [Double] = [
            0.00, 0.18, 0.36, 0.58, 0.84, 1.12
        ]

        // TO schedule — offset 0.12s so FROM and TO never tick in lockstep.
        let toSchedule: [Double] = [
            0.12, 0.30, 0.50, 0.72, 0.98, 1.26
        ]

        for (i, startTime) in fromSchedule.enumerated() {
            let name = pool[i % pool.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + startTime) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    vm.slotMachineFromName = name
                }
            }
        }

        // Pull TO names from the second half of the pool so FROM and TO
        // never display the same name simultaneously.
        for (i, startTime) in toSchedule.enumerated() {
            let name = pool[(i + pool.count / 2) % pool.count]
            DispatchQueue.main.asyncAfter(deadline: .now() + startTime) {
                withAnimation(.easeInOut(duration: 0.12)) {
                    vm.slotMachineToName = name
                }
            }
        }

        // End at 1.36s — rollDiceDual lands at 1.60s → ~0.24s linger.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.36) {
            isSlotMachineRunning = false
        }
    }

    // MARK: – Chaos page-indicator dots (rendered below the card)

    private var chaosDots: some View {
        HStack(spacing: 6) {
            // Left dot — filled in normal mode
            Circle()
                .fill(vm.isChaosMode ? Color.clear : accent)
                .overlay(
                    Circle().strokeBorder(
                        vm.isChaosMode ? Color(UIColor.tertiaryLabel) : Color.clear,
                        lineWidth: 0.5
                    )
                )
                .frame(width: 6, height: 6)
                .animation(.easeInOut(duration: 0.3), value: vm.isChaosMode)

            // Right dot — filled in chaos mode
            Circle()
                .fill(vm.isChaosMode ? Color(hex: "#8B5CF6") : Color.clear)
                .overlay(
                    Circle().strokeBorder(
                        vm.isChaosMode ? Color.clear : Color(UIColor.tertiaryLabel),
                        lineWidth: 0.5
                    )
                )
                .frame(width: 6, height: 6)
                .animation(.easeInOut(duration: 0.3), value: vm.isChaosMode)
        }
        .padding(.top, 6)
        .frame(maxWidth: .infinity, alignment: .center)
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

    /// Single DragGesture that resolves to one of: tap, long press, or swipe.
    /// Eliminates the tap/swipe race we had with separate pressGesture +
    /// swipeGesture on the same view — the recogniser sees every drag as
    /// either a press (if mostly stationary) or a swipe (if it crosses the
    /// horizontal-dominance threshold), never both.
    private var unifiedGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let adx = abs(dx)
                let ady = abs(dy)

                // Detect horizontal swipe intent — clear horizontal dominance
                // plus a minimum movement threshold to ignore micro-jitter.
                if adx > 12 && adx > ady * 1.5 {
                    if !swipeInProgress {
                        swipeInProgress = true
                        // Cancel long press — swipe takes over.
                        longPressWorkItem?.cancel()
                        longPressWorkItem = nil
                        didCompleteLongPress = false
                        isPressed = false
                        withAnimation(.easeOut(duration: 0.18)) {
                            holdProgress = 0
                            ringOpacity = 0
                        }
                        idleBreathOn = false
                    }

                    // Card follows the finger at 45% of drag, clamped ±40pt
                    // — a much more visible, physical pull than a subtle nudge.
                    swipeDragOffset = min(max(dx * 0.45, -40), 40)

                    // Bleed the chaos colour in proportion to swipe progress.
                    // 0 = full accent, 1 = full chaos dark.
                    let progress = min(adx / 44.0, 1.0)
                    chaosBledAmount = vm.isChaosMode
                        ? (1.0 - progress)
                        : progress

                    // Soft tick the moment we cross the 44pt commit threshold.
                    if adx >= 44 && !hasTickedThisSwipe {
                        hasTickedThisSwipe = true
                        let tick = UIImpactFeedbackGenerator(style: .soft)
                        tick.impactOccurred()
                    }

                    // Preview the CHAOS badge as soon as the user crosses
                    // the commit threshold while entering chaos. If they
                    // pull back under the threshold the preview retracts.
                    if adx >= 44 && !vm.isChaosMode {
                        if !swipeThresholdReached {
                            withAnimation(.spring(response: 0.3,
                                                  dampingFraction: 0.7)) {
                                swipeThresholdReached = true
                            }
                        }
                    } else if adx < 44 && swipeThresholdReached {
                        withAnimation(.spring(response: 0.3,
                                              dampingFraction: 0.7)) {
                            swipeThresholdReached = false
                        }
                    }
                    return
                }

                // Not a swipe — handle as press.
                if !swipeInProgress && !isPressed {
                    beginPress()
                }
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let adx = abs(dx)
                let ady = abs(dy)
                let wasSwipe = swipeInProgress
                swipeInProgress = false
                hasTickedThisSwipe = false
                swipeThresholdReached = false

                if wasSwipe && adx > 44 && adx > ady {
                    // Confirmed horizontal swipe.
                    if dx < 0 && !vm.isChaosMode {
                        // Right-to-left → enter chaos
                        let impact = UIImpactFeedbackGenerator(style: .heavy)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.35,
                                     dampingFraction: 0.7)) {
                            vm.isChaosMode = true
                        }
                    } else if dx > 0 && vm.isChaosMode {
                        // Left-to-right → exit chaos
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        withAnimation(.spring(response: 0.35,
                                     dampingFraction: 0.7)) {
                            vm.isChaosMode = false
                        }
                        // Cancel any in-flight slot-machine cycle so we
                        // don't leave orphaned names visible in the FROM
                        // or TO pills after exit.
                        isSlotMachineRunning = false
                        vm.slotMachineFromName = nil
                        vm.slotMachineToName = nil
                        slotMachineText = ""
                        slotTextOpacity = 0
                        slotTextOffsetY = 0
                    }
                    // Snap card back to centre + finalise bleed.
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        swipeDragOffset = 0
                    }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        chaosBledAmount = vm.isChaosMode ? 1.0 : 0.0
                    }
                    resetRing(animated: true)
                    isPressed = false
                    return
                }

                if wasSwipe {
                    // Incomplete swipe — rubber-band card back, restore
                    // bleed to match current chaos state.
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                        swipeDragOffset = 0
                        chaosBledAmount = vm.isChaosMode ? 1.0 : 0.0
                    }
                    return
                }

                // Not a swipe at all — fall through to the press flow,
                // which handles single-tap vs long-press completion via
                // `didCompleteLongPress` inside endPress().
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

        // Release the press-grab the instant the long press completes. The
        // existing spring on `isPressed` pops the card back to scale 1.0,
        // giving a "throw" feel instead of leaving the die compressed under
        // the user's finger while it tries to spin.
        isPressed = false

        withAnimation(.easeInOut(duration: 0.12)) {
            ringOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.18)) {
                ringOpacity = 0
            }
        }

        vm.setHasUsedLongPressRoll()

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
        if vm.isChaosMode {
            lastRollKind = .dual
            animateResultTransitionOut()
            animateDecorativeRollDual()
            pulsePattern(multiplier: 4, settle: 0.7)
            runSlotMachine()
            vm.rollDiceChaos()
            landingBounce(delay: 1.8)
            return
        }
        // Clear any stale TO override from an in-flight previous roll so
        // a rapid second tap doesn't briefly flash the old slot-machine name.
        vm.slotMachineToName = nil

        hasRolledOnce = true
        lastRollKind = .single
        // Single roll: only TO needs to transition out. FROM stays put,
        // so use the split-opacity helper instead of fading the entire badge.
        animateSingleRollTransitionOut()
        runSlotMachineNormalSingle()
        animateDecorativeRollSingle()
        pulsePattern(multiplier: 2, settle: 0.4)
        vm.rollDice()
        landingBounce(delay: 0.35)
    }

    private func triggerDualRoll() {
        if vm.isChaosMode {
            // Dual in chaos = same as single in chaos (everything is already random)
            triggerSingleRoll()
            return
        }
        // Clear stale overrides from an in-flight previous roll.
        vm.slotMachineFromName = nil
        vm.slotMachineToName = nil

        hasRolledOnce = true
        lastRollKind = .dual
        animateResultTransitionOut()
        runSlotMachineNormalDual()
        animateDecorativeRollDual()
        pulsePattern(multiplier: 6, settle: 0.7)
        vm.rollDiceDual()
        landingBounce(delay: 0.65)
    }

    private func animateDecorativeRollSingle() {
        withAnimation(.easeOut(duration: 0.12)) {
            pipOpacity = 0
        }

        // Scramble through 2 intermediate faces during spin
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            decorativeFace = Int.random(in: 1...6)
            withAnimation(.easeIn(duration: 0.06)) { pipOpacity = 0.5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            decorativeFace = Int.random(in: 1...6)
            withAnimation(.easeIn(duration: 0.06)) { pipOpacity = 0.5 }
        }

        let nextFace = Int.random(in: 1...6)
        let offset = Double.random(in: 180...270) * (Bool.random() ? 1 : -1)

        withAnimation(.interpolatingSpring(mass: 1, stiffness: 120,
                       damping: 14, initialVelocity: 8)) {
            extraDieRotation = offset
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            decorativeFace = nextFace
            withAnimation(.easeIn(duration: 0.12)) { pipOpacity = 1 }
            withAnimation(.interpolatingSpring(mass: 1, stiffness: 90,
                           damping: 12, initialVelocity: 6)) {
                extraDieRotation = 0
            }
        }
    }

    private func animateDecorativeRollDual() {
        withAnimation(.easeOut(duration: 0.1)) { pipOpacity = 0 }

        let finalFace = Int.random(in: 1...6)

        // Flash through 3 faces during the spin
        let scrambleTimes: [Double] = [0.12, 0.24, 0.36]
        for t in scrambleTimes {
            DispatchQueue.main.asyncAfter(deadline: .now() + t) {
                decorativeFace = Int.random(in: 1...6)
                withAnimation(.easeInOut(duration: 0.08)) {
                    pipOpacity = Double.random(in: 0.4...0.8)
                }
            }
        }

        // Fast-start, smooth-decelerate curve — die snaps into the spin
        // immediately on release (no perceived "stuck" frame) and slows
        // gracefully into the landing.
        withAnimation(.timingCurve(0.0, 0.0, 0.2, 1.0, duration: 0.55)) {
            extraDieRotation = 720 * (Bool.random() ? 1 : -1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            decorativeFace = finalFace
            withAnimation(.easeIn(duration: 0.12)) { pipOpacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 90,
                               damping: 14, initialVelocity: 6)) {
                    extraDieRotation = 0
                }
            }
        }
    }

    private func pulsePattern(multiplier: Double, settle: Double) {
        withAnimation(.easeIn(duration: 0.1)) {
            patternPulseMultiplier = multiplier
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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
        // Slot-machine collision guard: defer briefly if a prelude is
        // still in flight so the two animations don't compete.
        guard !isSlotMachineRunning else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                animateResultTransitionIn()
            }
            return
        }

        // Single roll uses the split-opacity path — FROM never moved on
        // tap-out, so we only need to bring TO back in. No reliance on
        // `pendingResultTransitionOut` since `animateResultTransitionOut`
        // wasn't called.
        if lastRollKind == .single {
            animateSingleRollTransitionIn()
            return
        }

        // Dual / chaos: full-badge fade-in (existing behaviour).
        guard pendingResultTransitionOut else { return }
        pendingResultTransitionOut = false
        resultOpacity = 0
        resultOffsetY = 4
        resultLandingScale = 0.85
        withAnimation(.easeIn(duration: 0.15)) {
            resultOpacity = 1
            resultOffsetY = 0
        }
        // Springy scale-up landing — runs alongside the fade-in so the
        // badge "lands" with a tiny bounce instead of a flat crossfade.
        withAnimation(.interpolatingSpring(mass: 0.8, stiffness: 200,
                       damping: 13, initialVelocity: 6)) {
            resultLandingScale = 1.0
        }
    }

    /// Single-roll-specific transition out. The slot machine keeps the TO
    /// half visible by switching the badge to the `vm.slotMachineToName`
    /// branch, so we don't fade `resultToOpacity` here — that would create
    /// a frame of invisible-TO before the cycle starts. We only flag the
    /// transition as pending in case anything else observes it.
    private func animateSingleRollTransitionOut() {
        pendingResultTransitionOut = true
        // Intentionally no-op on resultToOpacity / resultToOffsetY.
    }

    /// Counterpart that finalises TO state once the real value has
    /// landed. No opacity zeroing — the actual name swap is handled
    /// by `.contentTransition(.opacity)` + `.id()` on the Text view,
    /// so we only need to make sure resultTo* are at their resting state.
    private func animateSingleRollTransitionIn() {
        resultToOffsetY = 0
        resultToOpacity = 1.0
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

    private func landingBounce(delay: Double = 0.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeIn(duration: 0.08)) {
                cardLandingScale = 0.94
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(mass: 1, stiffness: 200,
                               damping: 12, initialVelocity: 10)) {
                    cardLandingScale = 1.0
                }
            }
        }
    }

    private func scheduleRestingTiltRandomize() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(.easeOut(duration: 0.22)) {
                restingRandomTilt = Double.random(in: -12...12)
                restingTiltX = Double.random(in: -18...18)
                restingTiltY = Double.random(in: -18...18)
            }
        }
    }

}

