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
    var body: some Scene {
        WindowGroup {
            ConverterView()
        }
        .modelContainer(for: [CustomUnit.self, FavoriteConversion.self])
    }
}
