//
//  MeasureAnythingApp.swift
//  MeasureAnything
//
//  Created by Vishal Ramanathan on 09/04/26.
//

import SwiftData
import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct MeasureAnythingApp: App {
    private let shouldShowLaunchAnimation: Bool

    init() {
        // SwiftData/CoreData expects Application Support to exist on first launch.
        // Creating it proactively avoids a first-run recovery path that can cause
        // a several-second blank screen before SwiftUI renders.
        Self.ensureApplicationSupportDirectoryExists()

        // Configure Firebase (Crashlytics). Requires GoogleService-Info.plist + Firebase SPM package.
        // See CrashlyticsManager.swift for full setup instructions.
        #if canImport(FirebaseCore)
        FirebaseApp.configure()
        #endif
        CrashlyticsManager.configure()

        // Play the launch animation on every cold launch (new process).
        // `LaunchAnimationView.hasPlayedThisSession` prevents replays on background/foreground.
        shouldShowLaunchAnimation = true
    }

    var body: some Scene {
        WindowGroup {
            RootLaunchShell(
                shouldShowLaunchAnimation: shouldShowLaunchAnimation
            )
            .preferredColorScheme(.light)
        }
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self])
    }

    private static func ensureApplicationSupportDirectoryExists() {
        guard let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return
        }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}

private struct RootLaunchShell: View {
    let shouldShowLaunchAnimation: Bool

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false

    @State private var showLaunchAnimation = true
    @State private var showOnboarding = false
    @State private var taxonomyStore: AppTaxonomyStore?
    @State private var converterViewModel: ConverterViewModel?
    @State private var didBoot = false

    var body: some View {
        ZStack {
            if let taxonomyStore, let converterViewModel {
                HomeView(vm: converterViewModel)
                    .environmentObject(taxonomyStore)
                    .environmentObject(converterViewModel)
            } else {
                Color.white.ignoresSafeArea()
            }

            if shouldShowLaunchAnimation, showLaunchAnimation {
                LaunchAnimationView(
                    onFinished: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showLaunchAnimation = false
                        }
                        if !hasSeenOnboarding {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    showOnboarding = true
                                }
                            }
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }

            if showOnboarding {
                OnboardingOverlayView(
                    onFinished: {
                        hasSeenOnboarding = true
                        withAnimation(.easeOut(duration: 0.25)) {
                            showOnboarding = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(9)
            }
        }
        .task {
            guard !didBoot else { return }
            didBoot = true

            // Render the first frame (launch overlay) ASAP, then do heavier work.
            await Task.yield()

            let taxonomy = AppTaxonomyStore()
            let vm = ConverterViewModel(taxonomy: taxonomy)
            taxonomyStore = taxonomy
            converterViewModel = vm
        }
    }
}
