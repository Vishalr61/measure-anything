import SwiftUI
import MeasureAnythingCore

@main
struct MeasureAnythingApp: App {
    private let shouldShowLaunchAnimation: Bool

    init() {
        // Keep first-frame smooth on fresh installs.
        Self.ensureApplicationSupportDirectoryExists()

        // Play the launch animation on every cold launch (new process).
        // `LaunchAnimationView.hasPlayedThisSession` prevents replays on background/foreground.
        shouldShowLaunchAnimation = true
    }

    var body: some Scene {
        WindowGroup {
            RootLaunchShell(shouldShowLaunchAnimation: shouldShowLaunchAnimation)
                .preferredColorScheme(.light)
        }
    }
}

private extension MeasureAnythingApp {
    static func ensureApplicationSupportDirectoryExists() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private struct RootLaunchShell: View {
    let shouldShowLaunchAnimation: Bool

    @State private var showLaunchAnimation = true
    @State private var showContent = false
    @State private var didBoot = false

    var body: some View {
        ZStack {
            if showContent {
                ConverterView()
            } else {
                Color.white.ignoresSafeArea()
            }

            if shouldShowLaunchAnimation, showLaunchAnimation {
                LaunchAnimationView(onFinished: { showLaunchAnimation = false })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task {
            guard !didBoot else { return }
            didBoot = true
            await Task.yield()
            showContent = true
        }
    }
}

