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

    init() {
        let taxonomy = AppTaxonomyStore()
        _taxonomyStore = StateObject(wrappedValue: taxonomy)
        _converterViewModel = StateObject(wrappedValue: ConverterViewModel(taxonomy: taxonomy))
        _ = FactCardStore.shared
    }

    var body: some Scene {
        WindowGroup {
            HomeView(vm: converterViewModel)
                .environmentObject(taxonomyStore)
                .environmentObject(converterViewModel)
                .background(Color.white)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self])
    }
}
