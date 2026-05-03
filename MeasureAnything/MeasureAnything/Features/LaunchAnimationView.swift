import SwiftUI
import UIKit

struct LaunchAnimationView: View {
    static var hasPlayedThisSession = false

    private enum Phase {
        case animating
        case held
        case dismissing
    }

    private struct Word: Identifiable {
        let id: Int
        let text: String
        let color: Color
    }

    private let words: [Word] = [
        Word(id: 0, text: "Elephants",   color: Color(hex: "#0F3D4A")),
        Word(id: 1, text: "Feathers",    color: Color(hex: "#27500A")),
        Word(id: 2, text: "Light years", color: Color(hex: "#854F0B")),
        Word(id: 3, text: "Heartbeats",  color: Color(hex: "#3C3489")),
        Word(id: 4, text: "Anything.",   color: Color(hex: "#000000")),
    ]

    private let subtitleText  = "meters, whales, and everything between"
    private let subtitleGray  = Color(hex: "#9A9A94")
    private let tapPromptText = "slide to start"
    private let tapPromptGray = Color(hex: "#C0C0B8")

    var onFinished: () -> Void

    // MARK: – Lifecycle flags
    @State private var didStart = false

    // MARK: – Root transform
    @State private var rootOpacity: Double = 1
    @State private var rootOffsetY: CGFloat = 0
    @State private var allowsTouches = true

    // MARK: – Phase (single source of truth for interaction gating)
    @State private var phase: Phase = .animating

    // MARK: – Interactive drag
    @State private var dragTranslationY: CGFloat = 0

    // MARK: – "Measure" word
    @State private var measureOpacity: Double = 0
    @State private var measureY: CGFloat = 8

    // MARK: – Cycling words
    @State private var wordOpacities: [Double] = Array(repeating: 0, count: 5)
    @State private var wordYs: [CGFloat]       = Array(repeating: 16, count: 5)

    // MARK: – Subtitle
    @State private var subtitleOpacity: Double = 0
    @State private var subtitleY: CGFloat = 6

    // MARK: – Tap-prompt
    @State private var tapPromptVisibleOpacity: Double = 0
    @State private var tapPromptPulse: Double = 0.4

    // MARK: – Animation task handle
    @State private var animationTask: Task<Void, Never>?

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Body
    // MARK: ─────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    measureText
                    cyclingWordStack
                }

                Text(subtitleText)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(subtitleGray)
                    .opacity(subtitleOpacity)
                    .offset(y: subtitleY)
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .offset(x: 6, y: -24)

            VStack {
                Spacer()
                VStack(spacing: 6) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tapPromptGray)
                        .opacity(tapPromptVisibleOpacity * tapPromptPulse)
                    Text(tapPromptText)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(tapPromptGray)
                        .opacity(tapPromptVisibleOpacity * tapPromptPulse)
                }
                .padding(.bottom, 80)
                .accessibilityHidden(true)
            }
        }
        .opacity(rootOpacity)
        .offset(y: rootOffsetY + dragTranslationY)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .allowsHitTesting(allowsTouches)
        .onTapGesture {
            handleProceedGesture()
        }
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    guard allowsTouches else { return }
                    let t = value.translation.height

                    switch phase {
                    case .held:
                        // Allow upward rubber-band drag only.
                        dragTranslationY = min(0, t)

                    case .animating:
                        // Any upward swipe during animation → snap to final state immediately.
                        // We use a low threshold (–20 pt) so it feels responsive.
                        if t < -20 {
                            snapToFinalState()
                        }

                    case .dismissing:
                        break
                    }
                }
                .onEnded { value in
                    guard allowsTouches else { return }
                    let t = value.translation.height

                    switch phase {
                    case .held:
                        if t < -100 {
                            Task { await finishWithSlide() }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                dragTranslationY = 0
                            }
                        }
                    case .animating:
                        // Swipe ended during animation (shouldn't normally reach here after
                        // snapToFinalState fires, but guard against residual drag offset).
                        withAnimation(.easeOut(duration: 0.15)) {
                            dragTranslationY = 0
                        }
                    case .dismissing:
                        break
                    }
                }
        )
        .task {
            guard !didStart else { return }
            didStart = true

            if UIAccessibility.isVoiceOverRunning {
                finishImmediately()
                return
            }

            guard !Self.hasPlayedThisSession else {
                finishImmediately()
                return
            }
            Self.hasPlayedThisSession = true

            let t = Task { await runAnimation() }
            animationTask = t
        }
        .accessibilityHidden(true)
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Sub-views
    // MARK: ─────────────────────────────────────────────────────────────────

    private var measureText: some View {
        Text("Measure")
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(Color.black)
            .opacity(measureOpacity)
            .offset(y: measureY)
    }

    private var cyclingWordStack: some View {
        ZStack(alignment: .leading) {
            Text("Anything.")
                .font(.system(size: 32, weight: .medium))
                .opacity(0) // baseline anchor

            ForEach(words) { word in
                Text(word.text)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(word.color)
                    .opacity(wordOpacities[word.id])
                    .offset(y: wordYs[word.id])
            }
        }
        .frame(height: 40, alignment: .leading)
        .alignmentGuide(.firstTextBaseline) { d in
            d[VerticalAlignment.firstTextBaseline]
        }
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Animation sequence
    // MARK: ─────────────────────────────────────────────────────────────────

    private func runAnimation() async {
        phase = .animating

        withAnimation(.easeOut(duration: 0.3)) {
            measureOpacity = 1; measureY = 0
        }

        await sleep(0.4)
        await wordIn(0);  await sleep(0.4)

        await transition(from: 0, to: 1, nextHold: 0.4)
        await transition(from: 1, to: 2, nextHold: 0.4)
        await transition(from: 2, to: 3, nextHold: 0.4)
        await transition(from: 3, to: 4, nextHold: 0.6)

        // Check for cancellation before mutating more UI state.
        guard !Task.isCancelled, phase == .animating else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            subtitleOpacity = 1; subtitleY = 0
        }

        await sleep(0.5)
        guard !Task.isCancelled, phase == .animating else { return }

        await showTapPrompt()
        phase = .held
    }

    private func wordIn(_ id: Int) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            wordOpacities[id] = 1; wordYs[id] = 0
        }
    }

    private func wordOut(_ id: Int) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            wordOpacities[id] = 0; wordYs[id] = -14
        }
    }

    private func transition(from: Int, to: Int, nextHold: TimeInterval) async {
        await wordOut(from)
        await sleep(0.08)
        await wordIn(to)
        await sleep(nextHold)
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Gesture handlers
    // MARK: ─────────────────────────────────────────────────────────────────

    private func handleProceedGesture() {
        switch phase {
        case .animating:
            snapToFinalState()
        case .held:
            Task { await finishWithFade() }
        case .dismissing:
            break
        }
    }

    /// Core fix: called the moment any swipe/tap is detected mid-animation.
    ///
    /// Strategy:
    /// 1. Flip phase to `.dismissing` immediately — this is the only lock we need.
    ///    No more animation mutations can fire from `runAnimation()` because every
    ///    `await sleep` is followed by a `guard phase == .animating` check.
    /// 2. Cancel the task (stops future sleeps from waking).
    /// 3. In a single, synchronous block: zero out all in-flight offsets and
    ///    set the final visible state — no animation, so nothing can "freeze" mid-tween.
    /// 4. Animate in the final typography cleanly from a known-good baseline.
    /// 5. Transition phase to `.held` so the user can swipe-up to dismiss.
    private func snapToFinalState() {
        guard phase == .animating else { return }

        // ① Lock out the animation loop immediately.
        phase = .dismissing   // temporary gate; we'll move to .held below

        // ② Cancel any pending sleeps.
        animationTask?.cancel()
        animationTask = nil

        // ③ Kill drag rubber-band immediately (no animation — avoids conflict).
        dragTranslationY = 0

        // ④ Zero all word states atomically, without animation.
        //    This is the key fix: we're not trying to animate over an in-flight animation.
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            for i in 0..<wordOpacities.count {
                wordOpacities[i] = 0
                wordYs[i] = 0      // reset offsets so the final word slides from neutral
            }
            // "Measure" should already be visible, but ensure it's locked.
            measureOpacity = 1
            measureY = 0
            // Reset subtitle so we can animate it in cleanly.
            subtitleOpacity = 0
            subtitleY = 6
            // Reset prompt too.
            tapPromptVisibleOpacity = 0
            tapPromptPulse = 0.4
        }

        // ⑤ Animate in the final state from a clean baseline.
        withAnimation(.easeOut(duration: 0.22)) {
            wordOpacities[4] = 1
            wordYs[4] = 0
        }

        // Stagger the subtitle slightly after the word lands.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeOut(duration: 0.2)) {
                subtitleOpacity = 1
                subtitleY = 0
            }
        }

        // ⑥ Show tap-prompt and hand back to the user.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.2)) {
                tapPromptVisibleOpacity = 1
            }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                tapPromptPulse = 0.9
            }
            phase = .held   // ← user can now swipe-up to dismiss
        }
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Dismiss transitions
    // MARK: ─────────────────────────────────────────────────────────────────

    private func finishImmediately() {
        allowsTouches = false
        rootOpacity = 0
        onFinished()
    }

    private func finishWithFade() async {
        guard allowsTouches, phase == .held else { return }
        phase = .dismissing
        allowsTouches = false
        withAnimation(.easeOut(duration: 0.28)) {
            rootOpacity = 0
            rootOffsetY = -60
        }
        await sleep(0.30)
        onFinished()
    }

    private func finishWithSlide() async {
        guard allowsTouches, phase == .held else { return }
        phase = .dismissing
        allowsTouches = false
        let target = -max(240, UIScreen.main.bounds.height * 0.38)
        withAnimation(.easeOut(duration: 0.28)) {
            rootOpacity = 0
            rootOffsetY = target
            dragTranslationY = 0
        }
        await sleep(0.30)
        onFinished()
    }

    // MARK: ─────────────────────────────────────────────────────────────────
    // MARK: Helpers
    // MARK: ─────────────────────────────────────────────────────────────────

    private func showTapPrompt() async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            tapPromptVisibleOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            tapPromptPulse = 0.9
        }
    }

    private func sleep(_ seconds: TimeInterval) async {
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }
}

#Preview {
    LaunchAnimationView(onFinished: {})
}
