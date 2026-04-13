import MeasureAnythingCore

enum UnitScaleGroups {
    static let groupOrder: [String] = [
        "Tiny", "Small", "Everyday",
        "Human scale", "Animals", "Large animals",
        "Room & street", "Home",
        "Landmark", "Vehicles", "Structures",
        "Geographic", "Nature", "Colossal",
        "Cosmic",
        "Instant", "Seconds", "Minutes", "Hours",
        "Days", "Months", "Years", "Lifescale",
        "Cosmic time",
        "Human", "Large", "Planetary",
        "Freezing", "Cool", "Warm", "Hot",
        "Scorching", "Extreme", "Stellar"
    ]

    private static let length: [String: String] = [
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

    private static let time: [String: String] = [
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

    private static let mass: [String: String] = [
        "grain_of_sand_mass": "Tiny", "feather": "Tiny",
        "grain_of_rice_mass": "Tiny", "paperclip_mass": "Tiny",
        "lego_brick": "Tiny", "hummingbird": "Tiny",

        "aa_battery": "Small", "golf_ball": "Small",
        "iphone": "Small", "human_heart": "Small",
        "can_of_soup": "Small",

        "bag_of_sugar": "Everyday", "litre_of_water": "Everyday",
        "human_brain": "Everyday", "chicken": "Everyday",
        "newborn_baby_mass": "Everyday", "bowling_ball": "Everyday",
        "human_skin": "Everyday", "human_skeleton": "Everyday",

        "house_cat": "Animals", "corgi": "Animals",
        "golden_retriever": "Animals", "labrador": "Animals",

        "washing_machine": "Home", "grand_piano": "Home",

        "great_white_shark": "Large animals",
        "rhino": "Large animals", "orca": "Large animals",
        "elephant": "Large animals", "t_rex": "Large animals",

        "small_car": "Vehicles",
        "london_double_decker_bus": "Vehicles",

        "blue_whale_mass": "Colossal", "iss": "Colossal",

        "eiffel_tower_mass": "Structures",
        "space_shuttle": "Structures",
        "great_pyramid": "Structures"
    ]

    private static let volume: [String: String] = [
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

    private static let temperature: [String: String] = [
        "absolute_zero": "Freezing", "deep_space": "Freezing",
        "liquid_nitrogen": "Freezing", "liquid_oxygen": "Freezing",
        "dry_ice": "Freezing", "antarctica_winter": "Freezing",

        "refrigerator": "Cool", "comfortable_room": "Cool",
        "swimming_pool": "Cool",

        "body_temp": "Warm", "high_fever": "Warm",
        "comfortable_bath": "Warm", "skin_pain": "Warm",
        "phone_overheat": "Warm",

        "laptop_lap": "Hot", "coffee_perfect": "Hot",
        "car_summer": "Hot", "fast_food_hot": "Hot",
        "sauna": "Hot", "gpu_overheat": "Hot",
        "cpu_throttle": "Hot", "boiling_water": "Hot",

        "battery_runaway": "Scorching", "paper_ignition": "Scorching",
        "pizza_oven": "Scorching", "venus_surface": "Scorching",
        "steel_softening": "Scorching", "aluminum_melting": "Scorching",

        "candle_flame": "Extreme", "lava": "Extreme",
        "jet_exhaust": "Extreme", "reentry_heat": "Extreme",
        "reactor_core": "Extreme", "welding_arc": "Extreme",

        "sun_surface": "Stellar", "lightning_bolt": "Stellar",
        "sun_core": "Stellar"
    ]

    static func scaleGroup(for unitID: String) -> String? {
        length[unitID]
            ?? time[unitID]
            ?? mass[unitID]
            ?? volume[unitID]
            ?? temperature[unitID]
    }

    static func grouped(_ units: [UnitDefinition]) -> [(title: String, units: [UnitDefinition])] {
        var buckets: [String: [UnitDefinition]] = [:]
        var ungrouped: [UnitDefinition] = []
        for unit in units {
            if let group = scaleGroup(for: unit.id) {
                buckets[group, default: []].append(unit)
            } else {
                ungrouped.append(unit)
            }
        }
        var result: [(String, [UnitDefinition])] = groupOrder.compactMap { name in
            guard let group = buckets[name], !group.isEmpty else { return nil }
            return (name, group)
        }
        if !ungrouped.isEmpty {
            result.append(("Other", ungrouped))
        }
        return result
    }
}
