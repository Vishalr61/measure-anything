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
    @StateObject private var taxonomyStore: AppTaxonomyStore
    @StateObject private var converterViewModel: ConverterViewModel
    private let shouldShowLaunchAnimation: Bool

    init() {
        let taxonomy = AppTaxonomyStore()
        _taxonomyStore = StateObject(wrappedValue: taxonomy)
        _converterViewModel = StateObject(wrappedValue: ConverterViewModel(taxonomy: taxonomy))
        _ = FactCardStore.shared

        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: "launchAnimationPlayCount")
        shouldShowLaunchAnimation = count < 5
        if shouldShowLaunchAnimation {
            defaults.set(count + 1, forKey: "launchAnimationPlayCount")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootLaunchShell(
                taxonomyStore: taxonomyStore,
                converterViewModel: converterViewModel,
                shouldShowLaunchAnimation: shouldShowLaunchAnimation
            )
            .preferredColorScheme(.light)
        }
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self])
    }
}

private struct RootLaunchShell: View {
    @ObservedObject var taxonomyStore: AppTaxonomyStore
    @ObservedObject var converterViewModel: ConverterViewModel
    let shouldShowLaunchAnimation: Bool

    @State private var showLaunchAnimation = true

    var body: some View {
        ZStack {
            HomeView(vm: converterViewModel)
                .environmentObject(taxonomyStore)
                .environmentObject(converterViewModel)

            if shouldShowLaunchAnimation, showLaunchAnimation {
                LaunchAnimationView(
                    onFinished: { showLaunchAnimation = false }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }
}
