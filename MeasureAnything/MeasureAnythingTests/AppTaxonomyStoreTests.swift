import Foundation
import MeasureAnythingCore
import MeasureAnythingTaxonomy
import Testing
@testable import MeasureAnything

@Suite("AppTaxonomyStore")
@MainActor
struct AppTaxonomyStoreTests {
    @Test func modeDisplayUsesSubgenreMetadata() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let d = store.modeDisplay(for: .normal)
        #expect(d.displayName == "Normal units")
        #expect(d.description == "Standard SI and common imperial units.")
    }

    @Test func modeDisplayFallsBackWhenRegistryNil() {
        let store = AppTaxonomyStore(injectedRegistry: nil, loadFailureMessage: "load failed")
        let d = store.modeDisplay(for: .normal)
        #expect(d.displayName == "Normal")
        #expect(d.description == nil)
    }

    @Test func categoryDisplayFallsBackWhenRegistryNil() {
        let store = AppTaxonomyStore(injectedRegistry: nil, loadFailureMessage: "load failed")
        let d = store.categoryDisplay(for: .length)
        #expect(d.displayName == "Length")
        #expect(d.description == nil)
    }

    @Test func categoryDisplayUsesRowOverrideWhenPresent() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal units","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd units","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom units","description":"c"}
          ],
          "items": [],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [
              {"unitCategoryRaw":"length","displayName":"Distance","description":"Test override"}
            ],
            "modes": [
              {"modeRaw":"normal","subgenreId":"measurement.normal"},
              {"modeRaw":"absurd","subgenreId":"measurement.absurd"},
              {"modeRaw":"custom","subgenreId":"measurement.custom"}
            ]
          }
        }
        """
        let reg = try TaxonomyRegistry(jsonData: Data(json.utf8))
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let d = store.categoryDisplay(for: .length)
        #expect(d.displayName == "Distance")
        #expect(d.description == "Test override")
    }

    @Test func bundledCategoryDescriptionForLength() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let d = store.categoryDisplay(for: .length)
        #expect(d.description == "Distance, height, and similar scales.")
    }

    @Test func bundledModeDescriptionForAbsurd() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let d = store.modeDisplay(for: .absurd)
        #expect(d.description == "Meme-friendly units backed by approximate real factors.")
    }

    @Test func searchPathResultFormatsDomainSubgenreItem() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let r = store.searchPathResult(forItemId: "item.measurement.normal.meter")
        #expect(r != nil)
        #expect(r?.pathLine == "Measurement / Normal units / Meter")
        #expect(r?.domainTitle == "Measurement")
        #expect(r?.subgenreTitle == "Normal units")
        #expect(r?.itemTitle == "Meter")
    }

    @Test func searchPathResultNilWhenRegistryMissing() {
        let store = AppTaxonomyStore(injectedRegistry: nil, loadFailureMessage: "x")
        #expect(store.searchPathResult(forItemId: "item.measurement.normal.meter") == nil)
    }

    @Test func searchPathResultNilForUnknownItem() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        #expect(store.searchPathResult(forItemId: "item.unknown") == nil)
    }

    @Test func converterCategoriesFallbackWhenRowsDoNotMapToEnums() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal units","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd units","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom units","description":"c"}
          ],
          "items": [],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [
              {"unitCategoryRaw":"not_a_real_category"}
            ],
            "modes": [
              {"modeRaw":"normal","subgenreId":"measurement.normal"},
              {"modeRaw":"absurd","subgenreId":"measurement.absurd"},
              {"modeRaw":"custom","subgenreId":"measurement.custom"}
            ]
          }
        }
        """
        let reg = try TaxonomyRegistry(jsonData: Data(json.utf8))
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        #expect(store.converterCategories == Array(UnitCategory.allCases))
    }
}
