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
                // ── What's in the app ────────────────────────────────────────
                Section {
                    NavigationLink(destination: AppFeaturesView()) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("What can Measure Anything do?")
                                Text("A tour of every feature")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "map")
                                .foregroundStyle(.primary)
                        }
                    }
                } header: {
                    sectionHeader("Discover")
                }

                // ── General ──────────────────────────────────────────────────
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

                // ── Display ──────────────────────────────────────────────────
                Section {
                    Toggle("Precision mode", isOn: $vm.precisionModeEnabled)
                } header: {
                    sectionHeader("Display")
                } footer: {
                    Text("When on, the converted value shows full decimal detail instead of smart grouping and scientific shorthand.")
                }

                // ── About ────────────────────────────────────────────────────
                Section {
                    LabeledContent("Version", value: versionString)

                    Button { sendFeedback() } label: {
                        Text("Send feedback")
                    }

                    Button { requestReview() } label: {
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

    // MARK: – Helpers

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
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Measure Anything feedback"),
            URLQueryItem(name: "body", value: ""),
        ]
        guard let url = components.url else { return }
        openURL(url)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: AppFeaturesView — "What can Measure Anything do?"
//
// A clean reference page describing every feature available in the app.
// Designed to be skimmable: icon + title + one-line description per feature.
// ─────────────────────────────────────────────────────────────────────────────

struct AppFeaturesView: View {
    var body: some View {
        List {
            Section {
                featureRow(
                    icon: "arrow.left.arrow.right.circle.fill",
                    color: Color(hex: "#1A5F73"),
                    title: "Unit conversion",
                    description: "Convert between standard and novelty units across Length, Mass, Time, Temperature, and Volume."
                )
                featureRow(
                    icon: "theatermasks.fill",
                    color: Color(hex: "#854F0B"),
                    title: "Novelty units",
                    description: "See results in Blue Whales, School Buses, Refrigerators, and dozens more absurd units."
                )
                featureRow(
                    icon: "arrow.left.arrow.right",
                    color: Color(hex: "#3D6B4A"),
                    title: "Swap units",
                    description: "Tap the swap button between the cards to instantly reverse FROM and TO."
                )
            } header: {
                sectionHeader("Converter")
            }

            Section {
                featureRow(
                    icon: "magnifyingglass",
                    color: Color(hex: "#3C3489"),
                    title: "Explore & search",
                    description: "Browse all units by category or search by name. Tap any two units to jump straight to that conversion."
                )
                featureRow(
                    icon: "info.circle.fill",
                    color: Color(hex: "#3D3580"),
                    title: "Fact cards",
                    description: "Tap the ⓘ button on any unit in Explore to open a fact card with interesting context about that unit."
                )
                featureRow(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    color: Color(hex: "#3C3489"),
                    title: "Recent conversions",
                    description: "The Explore tab remembers your recently used pairs for quick re-use."
                )
            } header: {
                sectionHeader("Explore")
            }

            Section {
                featureRow(
                    icon: "plus.circle.fill",
                    color: Color(hex: "#AF7D2A"),
                    title: "Custom units",
                    description: "Define your own units — \"My commute\", \"My dog\" — and use them in any conversion."
                )
                featureRow(
                    icon: "list.bullet.below.rectangle",
                    color: Color(hex: "#AF7D2A"),
                    title: "Manage custom units",
                    description: "View and delete your saved custom units from Settings → My custom units."
                )
            } header: {
                sectionHeader("Custom")
            }

            Section {
                featureRow(
                    icon: "square.and.arrow.up.fill",
                    color: Color(hex: "#1A5F73"),
                    title: "Share results",
                    description: "Tap Share on any conversion to generate a result card you can send to anyone."
                )
                featureRow(
                    icon: "heart.fill",
                    color: Color.red,
                    title: "Save favourites",
                    description: "Save unit pairs you use often. Saved pairs appear at the top of the converter."
                )
                featureRow(
                    icon: "dice.fill",
                    color: Color(hex: "#AF7D2A"),
                    title: "Roll the dice",
                    description: "Tap the dice card for a random unit. Long press or shake to randomise both FROM and TO. Works within the current category."
                )
                featureRow(
                    icon: "bolt.fill",
                    color: Color(hex: "#8B5CF6"),
                    title: "Chaos mode",
                    description: "Swipe the dice card left to enter chaos mode. Rolls pull from every category at once — anything goes."
                )
            } header: {
                sectionHeader("Extras")
            }

            Section {
                featureRow(
                    icon: "textformat.size",
                    color: Color.secondary,
                    title: "Precision mode",
                    description: "Toggle in Settings → Display to show full decimal detail instead of smart rounding."
                )
            } header: {
                sectionHeader("Settings")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("What's in the app")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

#Preview("Settings") {
    let taxonomy = AppTaxonomyStore()
    SettingsTabView()
        .environmentObject(ConverterViewModel(taxonomy: taxonomy))
        .modelContainer(for: CustomUnit.self, inMemory: true)
}

#Preview("Features") {
    NavigationStack {
        AppFeaturesView()
    }
}
