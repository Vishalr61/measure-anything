import SwiftUI
import MeasureAnythingCore

@main
struct MeasureAnythingApp: App {
    private let shouldShowLaunchAnimation: Bool

    init() {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "launchAnimationPlayCount")
        shouldShowLaunchAnimation = count < 5
        if shouldShowLaunchAnimation {
            defaults.set(count + 1, forKey: "launchAnimationPlayCount")
        }
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

