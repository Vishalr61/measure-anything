import StoreKit
import SwiftData
import SwiftUI

struct SettingsTabView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject private var vm: ConverterViewModel
    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        CustomUnitsListView()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("My custom units")
                            Text(customUnitsCountSubtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    sectionHeader("General")
                }

                Section {
                    Toggle("Precision mode", isOn: $vm.precisionModeEnabled)
                } header: {
                    sectionHeader("Display")
                } footer: {
                    Text("When on, the converted value shows full decimal detail instead of smart grouping and scientific shorthand.")
                }

                Section {
                    LabeledContent("Version", value: versionString)

                    Button {
                        sendFeedback()
                    } label: {
                        Text("Send feedback")
                    }

                    Button {
                        requestReview()
                    } label: {
                        Text("Rate on App Store")
                    }
                } header: {
                    sectionHeader("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
        }
    }

    private var customUnitsCountSubtitle: String {
        let count = customUnits.count
        if count == 0 { return "None yet" }
        return "\(count) unit\(count == 1 ? "" : "s")"
    }

    private var versionString: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func sendFeedback() {
        let email = "feedback@measureanything.app"
        let subject = "Measure Anything feedback"
        let body = ""

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else { return }
        openURL(url)
    }
}
