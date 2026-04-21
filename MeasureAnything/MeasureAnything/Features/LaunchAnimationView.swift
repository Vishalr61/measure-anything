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
        Word(id: 0, text: "Elephants", color: Color(hex: "#0F3D4A")),
        Word(id: 1, text: "Feathers", color: Color(hex: "#27500A")),
        Word(id: 2, text: "Light years", color: Color(hex: "#854F0B")),
        Word(id: 3, text: "Heartbeats", color: Color(hex: "#3C3489")),
        Word(id: 4, text: "Anything.", color: Color(hex: "#000000")),
    ]

    private let subtitleText = "meters, whales, and everything between"
    private let subtitleGray = Color(hex: "#9A9A94")
    private let tapPromptText = "slide to start"
    private let tapPromptGray = Color(hex: "#C0C0B8")

    var onFinished: () -> Void

    @State private var didStart = false
    @State private var rootOpacity: Double = 1
    @State private var rootOffsetY: CGFloat = 0
    @State private var allowsTouches = true
    @State private var phase: Phase = .animating
    @State private var dragTranslationY: CGFloat = 0

    @State private var measureOpacity: Double = 0
    @State private var measureY: CGFloat = 8

    @State private var wordOpacities: [Double] = Array(repeating: 0, count: 5)
    @State private var wordYs: [CGFloat] = Array(repeating: 16, count: 5)

    @State private var subtitleOpacity: Double = 0
    @State private var subtitleY: CGFloat = 6

    @State private var tapPromptVisibleOpacity: Double = 0
    @State private var tapPromptPulse: Double = 0.4

    @State private var animationTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

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
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .onChanged { value in
                    guard allowsTouches else { return }
                    let t = value.translation.height
                    switch phase {
                    case .held:
                        dragTranslationY = min(0, t)
                    case .animating:
                        // If user starts swiping up early, treat it like "skip to held".
                        if t < -50 {
                            handleProceedGesture()
                        }
                    case .dismissing:
                        break
                    }
                }
                .onEnded { value in
                    guard allowsTouches else { return }
                    let t = value.translation.height
                    if phase == .held {
                        if t < -120 {
                            Task { await finishWithSlide() }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                dragTranslationY = 0
                            }
                        }
                    } else {
                        dragTranslationY = 0
                    }
                }
        )
        .task {
            guard !didStart else { return }
            didStart = true

            // Skip entirely for VoiceOver users.
            if UIAccessibility.isVoiceOverRunning {
                finishImmediately()
                return
            }

            // Never replay within the same process (background/foreground).
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

    private var measureText: some View {
        Text("Measure")
            .font(.system(size: 32, weight: .medium))
            .foregroundStyle(Color.black)
            .opacity(measureOpacity)
            .offset(y: measureY)
    }

    private var cyclingWordStack: some View {
        ZStack(alignment: .leading) {
            // Baseline anchor: ensures container participates in baseline alignment.
            Text("Anything.")
                .font(.system(size: 32, weight: .medium))
                .opacity(0)

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

    private func runAnimation() async {
        phase = .animating

        // 0.0s: "Measure" appears.
        withAnimation(.easeOut(duration: 0.3)) {
            measureOpacity = 1
            measureY = 0
        }

        // 0.4s: first word slides in.
        await sleep(0.4)
        await wordIn(0)
        await sleep(0.4) // hold

        // 0.8s -> ... uniform transitions with 80ms gap.
        await transition(from: 0, to: 1, nextHold: 0.4)
        await transition(from: 1, to: 2, nextHold: 0.4)
        await transition(from: 2, to: 3, nextHold: 0.4)

        // 2.0s: Anything. in, hold longer.
        await transition(from: 3, to: 4, nextHold: 0.6)

        // 2.4s: subtitle fades in.
        withAnimation(.easeOut(duration: 0.3)) {
            subtitleOpacity = 1
            subtitleY = 0
        }

        // Hold indefinitely on the final title screen.
        await sleep(0.5)
        await showTapPrompt()
        phase = .held
    }

    private func wordIn(_ id: Int) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            wordOpacities[id] = 1
            wordYs[id] = 0
        }
    }

    private func wordOut(_ id: Int) async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: 0.2)) {
            wordOpacities[id] = 0
            wordYs[id] = -14
        }
    }

    private func transition(from: Int, to: Int, nextHold: TimeInterval) async {
        await wordOut(from)
        await sleep(0.08) // gap
        await wordIn(to)
        await sleep(nextHold)
    }

    private func handleProceedGesture() {
        switch phase {
        case .animating:
            animationTask?.cancel()
            animationTask = nil
            Task { await jumpToHeld() }
        case .held:
            Task { await finishWithFade() }
        case .dismissing:
            break
        }
    }

    private func finishImmediately() {
        allowsTouches = false
        rootOpacity = 0
        onFinished()
    }

    private func finishWithFade() async {
        guard allowsTouches else { return }
        phase = .dismissing
        allowsTouches = false
        withAnimation(.easeOut(duration: 0.3)) {
            rootOpacity = 0
            rootOffsetY = -80
        }
        await sleep(0.32)
        onFinished()
    }

    private func finishWithSlide() async {
        // Dismiss from an interactive drag position.
        guard allowsTouches else { return }
        phase = .dismissing
        allowsTouches = false
        let target = -max(220, UIScreen.main.bounds.height * 0.35)
        withAnimation(.easeOut(duration: 0.3)) {
            rootOpacity = 0
            rootOffsetY = target
            dragTranslationY = 0
        }
        await sleep(0.32)
        onFinished()
    }

    private func showTapPrompt() async {
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            tapPromptVisibleOpacity = 1
        }
        await sleep(0.02)
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            tapPromptPulse = 0.9
        }
    }

    private func jumpToHeld() async {
        guard phase == .animating else { return }

        // Ensure "Measure" is visible and steady.
        withAnimation(.easeOut(duration: 0.2)) {
            measureOpacity = 1
            measureY = 0
        }

        // Hide any currently animating words.
        withAnimation(.easeOut(duration: 0.15)) {
            for i in 0..<wordOpacities.count {
                wordOpacities[i] = 0
                wordYs[i] = 0
            }
        }

        // Show landing word + subtitle.
        withAnimation(.easeOut(duration: 0.2)) {
            wordOpacities[4] = 1
            wordYs[4] = 0
            subtitleOpacity = 1
            subtitleY = 0
        }

        await sleep(0.5)
        await showTapPrompt()
        phase = .held
    }

    private func sleep(_ seconds: TimeInterval) async {
        guard !Task.isCancelled else { return }
        try? await Task.sleep(for: .seconds(seconds))
    }
}

#Preview {
    LaunchAnimationView(onFinished: {})
}

