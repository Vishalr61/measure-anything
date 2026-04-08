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
    }

    var body: some Scene {
        WindowGroup {
            ConverterView(vm: converterViewModel)
                .environmentObject(taxonomyStore)
        }
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self])
    }
}
