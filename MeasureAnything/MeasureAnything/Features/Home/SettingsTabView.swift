import StoreKit
import SwiftData
import SwiftUI

struct SettingsTabView: View {
    private enum Keys {
        static let launchAnimationPlayCount = "launchAnimationPlayCount"
    }

    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \CustomUnit.name) private var customUnits: [CustomUnit]

    @State private var showClearHistoryAlert = false

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

                    Button(role: .destructive) {
                        showClearHistoryAlert = true
                    } label: {
                        Text("Clear conversion history")
                    }

                    Button {
                        UserDefaults.standard.set(0, forKey: Keys.launchAnimationPlayCount)
                        LaunchAnimationView.hasPlayedThisSession = false
                        Haptics.tap()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Reset launch animation")
                            Text("See the intro animation again")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    sectionHeader("General")
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
            .alert("Clear all conversion history?", isPresented: $showClearHistoryAlert) {
                Button("Clear", role: .destructive) {
                    ConversionHistory.shared.clearRecentPairs()
                    Haptics.tap()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes your Recently Used list on the Explore page. This can't be undone.")
            }
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
