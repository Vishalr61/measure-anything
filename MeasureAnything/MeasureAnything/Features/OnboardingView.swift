import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: OnboardingView
//
// Four slides, each with:
//   • A live mini-mockup of the actual feature (not just an icon)
//   • An animated pointer/callout that physically points at the key element
//   • Concise copy explaining WHY, not just what
//
// Style: clean white, the app's own colour palette, Syne-style bold numerals.
// The pointer is a curved SVG-style arrow drawn with SwiftUI Path — unique to
// the app's "measurement" aesthetic.
// ─────────────────────────────────────────────────────────────────────────────

struct OnboardingView: View {
    var onFinished: () -> Void

    @State private var currentPage = 0
    @State private var pointerBounce: CGFloat = 0   // drives pointer animation
    @State private var mockupAppear = false           // resets per slide

    private let slides: [OnboardingSlide] = OnboardingSlide.all

    private var currentAccent: Color { slides[currentPage].accentColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(slides.indices, id: \.self) { idx in
                        slideView(slides[idx])
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)
                .onChange(of: currentPage) { _, _ in
                    resetMockupAnimation()
                }

                bottomBar
            }
        }
        .onAppear { resetMockupAnimation() }
    }

    // MARK: – Slide layout

    private func slideView(_ slide: OnboardingSlide) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            // Mockup + pointer zone
            ZStack(alignment: .topLeading) {
                slide.mockup(mockupAppear)
                    .frame(maxWidth: .infinity)

                // Animated pointer arrow pointing at the highlighted element
                if let anchor = slide.pointerAnchor {
                    pointerArrow(slide: slide, anchor: anchor)
                        .offset(y: pointerBounce)
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true),
                            value: pointerBounce
                        )
                }
            }
            .frame(height: 320)
            .padding(.horizontal, 24)

            Spacer(minLength: 28)

            // Copy block
            VStack(spacing: 10) {
                Text(slide.headline)
                    .font(.system(size: 26, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(slide.body)
                    .font(.system(size: 15, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: "#6E6E6E"))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 16)
        }
    }

    // MARK: – Pointer arrow

    private func pointerArrow(slide: OnboardingSlide, anchor: OnboardingSlide.PointerAnchor) -> some View {
        // The pointer is a "measurement ruler tick" style indicator —
        // a short angled line ending in a filled circle, rotated to point at the element.
        VStack(spacing: 2) {
            // Label callout bubble
            Text(anchor.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(slide.accentColor)
                )

            // Stem
            Rectangle()
                .fill(slide.accentColor)
                .frame(width: 1.5, height: 18)

            // Arrowhead
            Triangle()
                .fill(slide.accentColor)
                .frame(width: 8, height: 6)
        }
        .offset(x: anchor.x, y: anchor.y)
    }

    // MARK: – Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 7) {
                ForEach(slides.indices, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentPage ? currentAccent : Color(hex: "#D8D8D5"))
                        .frame(width: idx == currentPage ? 20 : 7, height: 7)
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentPage)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }

            // CTA button
            Button {
                if currentPage < slides.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    onFinished()
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Next" : "Start measuring")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(currentAccent)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            if currentPage < slides.count - 1 {
                Button("Skip") { onFinished() }
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#B0B0A8"))
            } else {
                Color.clear.frame(height: 20)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: – Helpers

    private func resetMockupAnimation() {
        mockupAppear = false
        pointerBounce = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.4)) { mockupAppear = true }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pointerBounce = -6
            }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Slide model
// ─────────────────────────────────────────────────────────────────────────────

struct OnboardingSlide {
    struct PointerAnchor {
        let x: CGFloat
        let y: CGFloat
        let label: String
    }

    let headline: String
    let body: String
    let accentColor: Color
    let pointerAnchor: PointerAnchor?
    let mockup: (Bool) -> AnyView   // `appear` drives entrance animation

    // MARK: All slides

    static var all: [OnboardingSlide] {[
        unitConversionSlide,
        categoriesSlide,
        customModeSlide,
        exploreSlide,
    ]}

    // MARK: – Slide 1: Unit conversion

    static var unitConversionSlide: OnboardingSlide {
        OnboardingSlide(
            headline: "Convert anything,\ninto anything.",
            body: "Standard units and ridiculous ones — all in one place.",
            accentColor: Color(hex: "#1A5F73"),
            pointerAnchor: PointerAnchor(x: 16, y: 52, label: "tap to type"),
            mockup: { appear in
                AnyView(
                    UnitConversionMockup(appear: appear)
                )
            }
        )
    }

    // MARK: – Slide 2: Categories

    static var categoriesSlide: OnboardingSlide {
        OnboardingSlide(
            headline: "Five categories,\nhundreds of units.",
            body: "Length, Mass, Time, Temperature, Volume — plus absurd ones like Bowling Balls, T-Rexes and Eiffel Towers.",
            accentColor: Color(hex: "#3D6B4A"),
            pointerAnchor: PointerAnchor(x: 60, y: 0, label: "switch category"),
            mockup: { appear in
                AnyView(CategoriesMockup(appear: appear))
            }
        )
    }

    // MARK: – Slide 3: Custom mode

    static var customModeSlide: OnboardingSlide {
        OnboardingSlide(
            headline: "Make your own\nunits.",
            body: "Name anything, give it a size. Then use it to convert — and see the world in a whole new scale.",
            accentColor: Color(hex: "#3D3580"),
            pointerAnchor: PointerAnchor(x: 16, y: 198, label: "create unit"),
            mockup: { appear in
                AnyView(CustomModeMockup(appear: appear))
            }
        )
    }

    // MARK: – Slide 4: Explore

    static var exploreSlide: OnboardingSlide {
        OnboardingSlide(
            headline: "Explore, search,\nand discover.",
            body: "Browse by category or search. Tap any two units to jump straight to that conversion.",
            accentColor: Color(hex: "#8B3A2A"),
            pointerAnchor: PointerAnchor(x: 16, y: 128, label: "tap two units"),
            mockup: { appear in
                AnyView(ExploreMockup(appear: appear))
            }
        )
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Mockup views (mini live UI previews)
// ─────────────────────────────────────────────────────────────────────────────

// MARK: – Slide 1 mockup: converter card

private struct UnitConversionMockup: View {
    let appear: Bool

    var body: some View {
        VStack(spacing: 10) {
            // FROM card
            mockupCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FROM")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "#B0B0A8"))
                            .tracking(0.6)
                        // The big number — this is what the pointer targets
                        Text("175")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .opacity(appear ? 1 : 0)
                            .offset(x: appear ? 0 : -12)
                            .animation(.easeOut(duration: 0.35).delay(0.1), value: appear)
                    }
                    Spacer()
                    unitPill("Centimeters", color: Color(hex: "#1A5F73"))
                }
            }

            // Swap button
            HStack {
                Spacer()
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: "#1A5F73")))
                    .shadow(color: Color(hex: "#1A5F73").opacity(0.35), radius: 6, y: 3)
                Spacer()
            }

            // TO card
            mockupCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TO")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color(hex: "#B0B0A8"))
                            .tracking(0.6)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(appear ? "1.03" : "—")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#1A5F73"))
                                .contentTransition(.numericText())
                                .animation(.easeOut(duration: 0.5).delay(0.25), value: appear)
                        }
                        Text("175 cm = 1.03 refrigerators")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#B0B0A8"))
                            .opacity(appear ? 1 : 0)
                            .animation(.easeOut(duration: 0.3).delay(0.45), value: appear)
                    }
                    Spacer()
                    unitPill("Refrigerators", color: Color(hex: "#1A5F73"))
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: – Slide 2 mockup: category chips

private struct CategoriesMockup: View {
    let appear: Bool

    private let chips: [(String, String, Color)] = [
        ("ruler",              "Length",      Color(hex: "#1A5F73")),
        ("scalemass",          "Mass",        Color(hex: "#3D6B4A")),
        ("clock",              "Time",        Color(hex: "#3D3580")),
        ("thermometer.medium", "Temperature", Color(hex: "#8B3A2A")),
        ("drop",               "Volume",      Color(hex: "#AF7D2A")),
    ]

    var body: some View {
        VStack(spacing: 14) {
            // Chip row (pointer targets the first chip)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(chips.enumerated()), id: \.offset) { idx, chip in
                        categoryChip(
                            icon: chip.0,
                            name: chip.1,
                            color: chip.2,
                            isSelected: idx == 1
                        )
                        .opacity(appear ? 1 : 0)
                        .offset(y: appear ? 0 : 10)
                        .animation(.easeOut(duration: 0.3).delay(Double(idx) * 0.07), value: appear)
                    }
                }
                .padding(.horizontal, 4)
            }

            // Mini unit grid below
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(["Kilogram", "Pound", "Ounce", "Bowling\nBall", "T-Rex", "Eiffel\nTower"].enumerated()), id: \.offset) { idx, name in
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(idx < 3 ? Color(hex: "#E1F5EE") : Color(hex: "#EDF4EF"))
                        )
                        .foregroundStyle(idx < 3 ? Color(hex: "#085041") : Color(hex: "#3D6B4A"))
                        .opacity(appear ? 1 : 0)
                        .animation(.easeOut(duration: 0.3).delay(0.4), value: appear)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func categoryChip(icon: String, name: String, color: Color, isSelected: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
            Text(name)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(isSelected ? .white : color)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(isSelected ? color : color.opacity(0.12)))
    }
}

// MARK: – Slide 3 mockup: custom unit form

private struct CustomModeMockup: View {
    let appear: Bool

    var body: some View {
        VStack(spacing: 12) {
            mockupCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("WHAT IS IT?")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B0B0A8"))
                        .tracking(0.6)

                    // Simulated text field with placeholder
                    HStack {
                        Text("My commute")
                            .font(.system(size: 16))
                            .foregroundStyle(.primary)
                            .opacity(appear ? 1 : 0)
                            .offset(x: appear ? 0 : -8)
                            .animation(.easeOut(duration: 0.35).delay(0.1), value: appear)
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: "#F5F5F2")))
                }
            }

            mockupCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("HOW BIG IS IT?")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(hex: "#B0B0A8"))
                        .tracking(0.6)

                    HStack(alignment: .center, spacing: 12) {
                        Text(appear ? "12.4" : "0")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                            .animation(.easeOut(duration: 0.45).delay(0.2), value: appear)
                        Spacer()
                        unitPill("Kilometers", color: Color(hex: "#854F0B"))
                    }
                }
            }

            // Preview card
            if appear {
                HStack(spacing: 10) {
                    Text("1 My commute = 12.4 km ≈ 13 blue whales")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#854F0B"))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#FAEEDA"))
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.35).delay(0.35), value: appear)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: – Slide 4 mockup: explore with two-tap flow

private struct ExploreMockup: View {
    let appear: Bool
    @State private var firstTapped = false
    @State private var secondTapped = false

    var body: some View {
        VStack(spacing: 10) {
            // Search bar mockup
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#B4B2A9"))
                Text("kilometer, elephant, year...")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#B4B2A9"))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(hex: "#F0F0F3"))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: appear)

            // Two-tap instruction strip
            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#3C3489"))
                Text("Tap FROM, then tap TO to convert instantly")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(hex: "#3C3489"))
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(hex: "#EEEDFE"))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.1), value: appear)

            // Unit rows showing the selection flow
            VStack(spacing: 0) {
                exploreRow(
                    name: "Kilometer",
                    detail: "1,000 m",
                    isSelected: firstTapped,
                    badge: firstTapped ? "FROM ✓" : "FROM",
                    accentColor: Color(hex: "#3C3489"),
                    delay: 0.15,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.2)) { firstTapped = true }
                    }
                )
                Divider().padding(.leading, 16)
                exploreRow(
                    name: "Marathon",
                    detail: "42.195 km",
                    isSelected: secondTapped,
                    badge: firstTapped ? (secondTapped ? "TO ✓" : "TO") : "FROM",
                    accentColor: Color(hex: "#3C3489"),
                    delay: 0.22,
                    onTap: {
                        if firstTapped {
                            withAnimation(.easeInOut(duration: 0.2)) { secondTapped = true }
                        }
                    }
                )
                Divider().padding(.leading, 16)
                exploreRow(
                    name: "Blue Whale",
                    detail: "≈ 25 m",
                    isSelected: false,
                    badge: "FROM",
                    accentColor: Color(hex: "#3C3489"),
                    delay: 0.29,
                    onTap: {}
                )
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )
            .opacity(appear ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(0.15), value: appear)
        }
        .padding(.horizontal, 4)
        .onAppear {
            // Auto-demo the tap flow
            if appear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { firstTapped = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation { secondTapped = true }
                    }
                }
            }
        }
        .onChange(of: appear) { _, newVal in
            if newVal {
                firstTapped = false; secondTapped = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation { firstTapped = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation { secondTapped = true }
                    }
                }
            } else {
                firstTapped = false; secondTapped = false
            }
        }
    }

    private func exploreRow(
        name: String,
        detail: String,
        isSelected: Bool,
        badge: String,
        accentColor: Color,
        delay: Double,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 3, height: 28)
                    .opacity(isSelected ? 1 : 0.3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? accentColor : .primary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(isSelected ? accentColor : accentColor.opacity(0.12))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? accentColor.opacity(0.07) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Shared mockup helpers
// ─────────────────────────────────────────────────────────────────────────────

private func mockupCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#F5F5F2"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
        )
}

private func unitPill(_ name: String, color: Color) -> some View {
    Text(name)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
        .lineLimit(1)
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Triangle arrowhead shape
// ─────────────────────────────────────────────────────────────────────────────

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Preview
// ─────────────────────────────────────────────────────────────────────────────

#Preview {
    OnboardingView(onFinished: {})
}