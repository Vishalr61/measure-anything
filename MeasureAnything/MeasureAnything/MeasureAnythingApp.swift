//
//  MeasureAnythingApp.swift
//  MeasureAnything
//
//  Created by Vishal Ramanathan on 09/04/26.
//

import SwiftData
import SwiftUI

@main
struct MeasureAnythingApp: App {
    private let shouldShowLaunchAnimation: Bool

    init() {
        // SwiftData/CoreData expects Application Support to exist on first launch.
        // Creating it proactively avoids a first-run recovery path that can cause
        // a several-second blank screen before SwiftUI renders.
        Self.ensureApplicationSupportDirectoryExists()

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

    @State private var showLaunchAnimation = true
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
                    onFinished: { showLaunchAnimation = false }
                )
                .transition(.opacity)
                .zIndex(10)
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
