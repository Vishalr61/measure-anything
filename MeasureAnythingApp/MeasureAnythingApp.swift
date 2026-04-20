import SwiftUI
import MeasureAnythingCore

@main
struct MeasureAnythingApp: App {
    private let shouldShowLaunchAnimation: Bool

    init() {
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

private struct RootLaunchShell: View {
    let shouldShowLaunchAnimation: Bool

    @State private var showLaunchAnimation = true

    var body: some View {
        ZStack {
            ConverterView()

            if shouldShowLaunchAnimation, showLaunchAnimation {
                LaunchAnimationView(onFinished: { showLaunchAnimation = false })
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
    }
}

