import XCTest
@testable import MeasureAnythingCore

final class CoreConversionTests: XCTestCase {
    func testSeedNormalUnitsExist() throws {
        let registry = try UnitRegistry(units: SeedNormalUnits.all)

        XCTAssertNoThrow(try registry.unit(id: "meter"))
        XCTAssertNoThrow(try registry.unit(id: "kilogram"))
        XCTAssertNoThrow(try registry.unit(id: "second"))
        XCTAssertNoThrow(try registry.unit(id: "liter"))
        XCTAssertNoThrow(try registry.unit(id: "celsius"))
        XCTAssertNoThrow(try registry.unit(id: "fahrenheit"))
        XCTAssertNoThrow(try registry.unit(id: "kelvin"))
    }

    func testAbsurdUnitsLoadFromJSONPerCategory() throws {
        let store = AbsurdUnitStore()

        let length = try store.load(category: .length)
        let lengthIDs = Set(length.map(\.id))
        XCTAssertGreaterThanOrEqual(lengthIDs.count, 50)
        XCTAssertFalse(lengthIDs.contains("school_bus"))
        for required in ["banana", "fridge", "bus", "blue_whale", "spider_silk", "distance_light_second"] {
            XCTAssertTrue(lengthIDs.contains(required), "Expected length absurd id missing: \(required)")
        }

        let mass = try store.load(category: .mass)
        XCTAssertEqual(Set(mass.map(\.id)), Set(["cat", "bowling_ball", "microwave", "elephant"]))

        let time = try store.load(category: .time)
        XCTAssertEqual(Set(time.map(\.id)), Set(["coffee_break", "gym_session", "one_episode", "bad_meeting"]))

        let volume = try store.load(category: .volume)
        XCTAssertEqual(Set(volume.map(\.id)), Set(["soda_can", "wine_glass", "bathtub", "bucket"]))
    }

    func testRegistryRejectsDuplicateIDs() throws {
        let units = SeedNormalUnits.length + SeedNormalUnits.length
        XCTAssertThrowsError(try UnitRegistry(units: units)) { error in
            guard let err = error as? UnitRegistry.RegistryError else {
                return XCTFail("Unexpected error: \(error)")
            }
            switch err {
            case .duplicateUnitID:
                break
            default:
                XCTFail("Expected duplicateUnitID, got \(err)")
            }
        }
    }

    func testModeFilteringWorks() throws {
        let store = AbsurdUnitStore()
        let absurd = try store.loadAll()
        let registry = try UnitRegistry(units: SeedNormalUnits.all + absurd)

        let normalLength = registry.units(in: .length, includeKinds: UnitRegistry.Mode.normal.includedKinds)
        XCTAssertTrue(normalLength.allSatisfy { $0.kind == .normal })

        let absurdLength = registry.units(in: .length, includeKinds: UnitRegistry.Mode.absurd.includedKinds)
        XCTAssertTrue(absurdLength.contains(where: { $0.kind == .absurd }))
        XCTAssertTrue(absurdLength.contains(where: { $0.kind == .normal }))

        let customLength = registry.units(in: .length, includeKinds: UnitRegistry.Mode.custom.includedKinds)
        XCTAssertTrue(customLength.allSatisfy { $0.kind == .normal || $0.kind == .custom })
    }

    func testBasicConversionsNormalAndAbsurd() throws {
        let store = AbsurdUnitStore()
        let registry = try UnitRegistry(units: SeedNormalUnits.all + store.loadAll())
        let engine = ConverterEngine(registry: registry)

        // 1 kilometer -> meter = 1000
        let kmToM = try engine.convert(1, from: "kilometer", to: "meter")
        XCTAssertEqual(kmToM.outputValue, 1000, accuracy: 1e-12)

        // 1 banana -> meter = 0.178
        let bananaToM = try engine.convert(1, from: "banana", to: "meter")
        XCTAssertEqual(bananaToM.outputValue, 0.178, accuracy: 1e-12)

        // 10 meter -> banana
        let mToBanana = try engine.convert(10, from: "meter", to: "banana")
        XCTAssertEqual(mToBanana.outputValue, 10 / 0.178, accuracy: 1e-12)

        // 1 elephant -> kilogram = 6000
        let elephantToKg = try engine.convert(1, from: "elephant", to: "kilogram")
        XCTAssertEqual(elephantToKg.outputValue, 6000, accuracy: 1e-12)

        // 2 hours -> coffee_break (2 hours = 7200s, coffee_break=900s, result=8)
        let hoursToCoffee = try engine.convert(2, from: "hour", to: "coffee_break")
        XCTAssertEqual(hoursToCoffee.outputValue, 8, accuracy: 1e-12)
    }

    func testTemperatureConversions() throws {
        let registry = try UnitRegistry(units: SeedNormalUnits.all)
        let engine = ConverterEngine(registry: registry)

        // 0 celsius -> kelvin = 273.15
        let cToK = try engine.convert(0, from: "celsius", to: "kelvin")
        XCTAssertEqual(cToK.outputValue, 273.15, accuracy: 1e-12)

        // 32 fahrenheit -> celsius = 0
        let fToC = try engine.convert(32, from: "fahrenheit", to: "celsius")
        XCTAssertEqual(fToC.outputValue, 0, accuracy: 1e-12)
    }

    func testAbsurdJSONRejectsTemperatureUnits() throws {
        let store = AbsurdUnitStore()

        let json = """
        [
          {
            "id": "evil_temp",
            "name": "EvilTemp",
            "category": "temperature",
            "baseUnit": "kelvin",
            "kind": "absurd",
            "conversionStyle": "multiplicative",
            "factor": 1.0
          }
        ]
        """.data(using: .utf8)!

        XCTAssertThrowsError(try store.decodeAndValidate(data: json, category: .temperature))
    }

    func testValidationRules() throws {
        // multiplicative units require positive factor
        XCTAssertThrowsError(
            try UnitDefinition(
                id: "bad_factor",
                name: "BadFactor",
                category: .length,
                baseUnit: "meter",
                kind: .normal,
                conversionStyle: .multiplicative,
                factor: 0
            )
        )

        // base unit mismatch fails
        XCTAssertThrowsError(
            try UnitDefinition(
                id: "wrong_base",
                name: "WrongBase",
                category: .length,
                baseUnit: "kilogram",
                kind: .normal,
                conversionStyle: .multiplicative,
                factor: 1
            )
        )
    }
}

