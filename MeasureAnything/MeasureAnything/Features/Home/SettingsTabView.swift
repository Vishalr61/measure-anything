import SwiftUI

/// Placeholder settings surface for bottom navigation.
struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("More options coming soon.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
