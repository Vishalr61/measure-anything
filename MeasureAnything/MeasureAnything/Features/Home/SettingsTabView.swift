import SwiftUI

struct SettingsTabView: View {
    @EnvironmentObject private var vm: ConverterViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Standard units only", isOn: $vm.standardUnitsOnly)
                } footer: {
                    Text("Hide absurd and custom units from the converter")
                        .font(.footnote)
                }

                Section {
                    NavigationLink {
                        CustomUnitsListView()
                    } label: {
                        Text("My custom units")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
