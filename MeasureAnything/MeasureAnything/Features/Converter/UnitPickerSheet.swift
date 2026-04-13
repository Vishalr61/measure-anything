import SwiftUI
import MeasureAnythingCore

struct UnitPickerSheet: View {
    let units: [UnitDefinition]
    let selectedID: UnitDefinition.ID
    let accent: Color
    let onSelect: (UnitDefinition.ID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    // MARK: - Scale group ordering

    private static let scaleGroupOrder: [String] = [
        "Tiny", "Small", "Everyday",
        "Human scale", "Animals", "Large animals",
        "Room & street", "Home",
        "Landmark", "Vehicles", "Structures",
        "Geographic", "Nature", "Colossal",
        "Cosmic",
        "Instant", "Seconds", "Minutes", "Hours",
        "Days", "Months", "Years", "Lifescale",
        "Cosmic time",
        "Human", "Large", "Planetary"
    ]

    // MARK: - Per-category scale mappings (keyed by unit ID)

    private static let lengthScaleGroups: [String: String] = [
        "spider_silk": "Tiny", "red_blood_cell": "Tiny",
        "human_hair": "Tiny", "grain_of_sand": "Tiny",
        "ant": "Small", "paperclip": "Small",
        "grain_of_rice": "Small", "credit_card": "Small",
        "pencil": "Small", "toothbrush": "Small",
        "chopstick": "Small", "banana": "Small",
        "smartphone": "Human scale", "newborn_baby": "Human scale",
        "footlong_sub": "Human scale", "wine_bottle": "Human scale",
        "arm_span": "Human scale", "door": "Human scale",
        "human_height": "Human scale", "yoga_mat": "Human scale",
        "guitar": "Human scale", "fridge": "Human scale",
        "suitcase": "Human scale", "park_bench": "Human scale",
        "basketball_hoop": "Room & street",
        "swimming_pool_depth": "Room & street",
        "car": "Room & street", "double_decker_bus": "Room & street",
        "bus": "Room & street", "telephone_pole": "Room & street",
        "bowling_lane": "Room & street", "tennis_court": "Room & street",
        "short_pool": "Room & street", "city_block": "Room & street",
        "subway_car": "Room & street", "football_field": "Room & street",
        "olympic_pool": "Landmark", "boeing_747": "Landmark",
        "aircraft_carrier": "Landmark", "statue_of_liberty": "Landmark",
        "eiffel_tower": "Landmark", "big_ben": "Landmark",
        "empire_state_building": "Landmark", "burj_khalifa": "Landmark",
        "blue_whale": "Nature", "giraffe": "Nature",
        "mount_everest": "Geographic", "marathon": "Geographic",
        "great_wall": "Geographic", "amazon_river": "Geographic",
        "nile_river": "Geographic", "new_york_to_london": "Geographic",
        "australia_width": "Geographic", "london_to_sydney": "Geographic",
        "earth_circumference": "Geographic",
        "earth_to_moon": "Cosmic", "earth_to_sun": "Cosmic",
        "distance_light_second": "Cosmic", "comet_tail": "Cosmic",
        "distance_light_year": "Cosmic"
    ]

    private static let timeScaleGroups: [String: String] = [
        "blink": "Instant", "heartbeat": "Instant",
        "light_travel_earth_moon": "Instant",
        "olympic_100m": "Seconds",
        "nap": "Minutes", "coffee_break": "Minutes",
        "tv_episode": "Minutes", "gym_session": "Minutes",
        "bad_meeting": "Minutes", "song": "Minutes",
        "toilet_scroll": "Minutes", "commute": "Minutes",
        "work_day": "Hours", "mars_day": "Hours",
        "week": "Days", "lunar_month": "Days",
        "month": "Months",
        "dog_year": "Years", "year": "Years", "decade": "Years",
        "human_lifespan": "Lifescale",
        "since_dinosaurs": "Cosmic time",
        "age_of_universe": "Cosmic time"
    ]

    private static let massScaleGroups: [String: String] = [
        "grain_of_rice_mass": "Tiny", "paperclip_mass": "Tiny",
        "bag_of_sugar": "Everyday", "chicken": "Everyday",
        "newborn_baby_mass": "Everyday", "bowling_ball": "Everyday",
        "house_cat": "Animals", "golden_retriever": "Animals",
        "rhino": "Large animals", "elephant": "Large animals",
        "t_rex": "Large animals",
        "grand_piano": "Vehicles", "small_car": "Vehicles",
        "london_double_decker_bus": "Vehicles",
        "eiffel_tower_mass": "Structures",
        "space_shuttle": "Structures",
        "blue_whale_mass": "Colossal"
    ]

    private static let volumeScaleGroups: [String: String] = [
        "teaspoon_vol": "Tiny",
        "can_of_soda": "Small", "soda_can": "Small",
        "wine_bottle_vol": "Small", "wine_glass": "Small",
        "milk_carton": "Small", "bucket": "Small",
        "stomach": "Human", "blood_volume": "Human",
        "fuel_tank": "Human",
        "bathtub": "Home", "hot_tub": "Home",
        "olympic_pool_vol": "Large",
        "earths_ocean": "Planetary"
    ]

    private static let temperatureScaleGroups: [String: String] = [
        "deep_space": "Cosmic",
        "comfortable_room": "Everyday",
        "body_temp": "Human",
        "pizza_oven": "Everyday",
        "candle_flame": "Everyday",
        "lava": "Nature",
        "sun_surface": "Cosmic"
    ]

    // MARK: - Derived lists

    private func scaleGroup(for unit: UnitDefinition) -> String? {
        Self.lengthScaleGroups[unit.id]
            ?? Self.timeScaleGroups[unit.id]
            ?? Self.massScaleGroups[unit.id]
            ?? Self.volumeScaleGroups[unit.id]
            ?? Self.temperatureScaleGroups[unit.id]
    }

    private var normalUnits: [UnitDefinition] {
        units.filter { $0.kind == .normal }
    }

    private var absurdUnits: [UnitDefinition] {
        units.filter { $0.kind != .normal }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var filteredUnits: [UnitDefinition] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        return units.filter { $0.name.lowercased().contains(query) }
    }

    private var groupedAbsurd: [(title: String, units: [UnitDefinition])] {
        var grouped: [String: [UnitDefinition]] = [:]
        var ungrouped: [UnitDefinition] = []
        for unit in absurdUnits {
            if let group = scaleGroup(for: unit) {
                grouped[group, default: []].append(unit)
            } else {
                ungrouped.append(unit)
            }
        }
        var result: [(String, [UnitDefinition])] = Self.scaleGroupOrder.compactMap { name in
            guard let group = grouped[name], !group.isEmpty else { return nil }
            return (name, group)
        }
        if !ungrouped.isEmpty {
            result.append(("Other", ungrouped))
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Divider()
                unitList
            }
            .navigationTitle("Choose unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: "#B4B2A9"))
                .font(.system(size: 15))
            TextField("Search units…", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(hex: "#B4B2A9"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(hex: "#F0F0F3"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var unitList: some View {
        List {
            if isSearching {
                if filteredUnits.isEmpty {
                    Text("No units match \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredUnits, id: \.id) { unit in
                        unitRow(unit)
                    }
                }
            } else {
                if !normalUnits.isEmpty {
                    Section {
                        ForEach(normalUnits, id: \.id) { unit in
                            unitRow(unit)
                        }
                    } header: {
                        sectionHeader("Standard")
                    }
                }

                if !absurdUnits.isEmpty {
                    ForEach(groupedAbsurd, id: \.title) { group in
                        Section {
                            ForEach(group.units, id: \.id) { unit in
                                unitRow(unit)
                            }
                        } header: {
                            sectionHeader(group.title)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func unitRow(_ unit: UnitDefinition) -> some View {
        Button {
            Haptics.tap()
            onSelect(unit.id)
            dismiss()
        } label: {
            HStack {
                Text(unit.name)
                    .font(.system(size: 16))
                    .foregroundStyle(.primary)
                Spacer()
                if unit.id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(unit.id == selectedID ? accent.opacity(0.06) : Color.clear)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(hex: "#888780"))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.top, 4)
    }
}
