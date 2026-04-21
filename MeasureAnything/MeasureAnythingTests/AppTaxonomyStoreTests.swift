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

    @Test func searchItemsReturnsEmptyWhenRegistryMissing() {
        let store = AppTaxonomyStore(injectedRegistry: nil, loadFailureMessage: "x")
        #expect(store.searchItems(query: "meter").isEmpty)
    }

    @Test func searchItemsBlankQueryReturnsBrowseList() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        #expect(!store.searchItems(query: "   ").isEmpty)
    }

    @Test func searchExactTitleRanksBeforeExactSynonym() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"Measurement","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [
            {
              "id":"item.b",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Zebra",
              "description":"d",
              "synonyms": ["uniquequerytoken"]
            },
            {
              "id":"item.a",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Uniquequerytoken",
              "description":"d"
            }
          ],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
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
        let rows = store.searchItems(query: "uniquequerytoken")
        #expect(rows.count == 2)
        #expect(rows[0].id == "item.a")
        #expect(rows[1].id == "item.b")
    }

    @Test func searchPrefixTitleRanksBeforeExactSynonym() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"Measurement","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [
            {
              "id":"item.syn",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Z",
              "description":"d",
              "synonyms": ["alphabeta"]
            },
            {
              "id":"item.pre",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Alphabetical",
              "description":"d"
            }
          ],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
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
        let rows = store.searchItems(query: "alpha")
        #expect(rows.count == 2)
        #expect(rows[0].id == "item.pre")
        #expect(rows[1].id == "item.syn")
    }

    @Test func searchCategoryFilterExcludesOtherCategories() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"Measurement","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [
            {
              "id":"item.len",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"LenThing",
              "description":"d",
              "tags":["findme"],
              "unitCategoryRaw":"length"
            },
            {
              "id":"item.mass",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"MassThing",
              "description":"d",
              "tags":["findme"],
              "unitCategoryRaw":"mass"
            }
          ],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"},{"unitCategoryRaw":"mass"}],
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
        let rows = store.searchItems(query: "findme", filters: TaxonomySearchFilters(unitCategory: .length))
        #expect(rows.count == 1)
        #expect(rows[0].id == "item.len")
    }

    @Test func searchResultPathMatchesSearchPathResult() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let rows = store.searchItems(query: "meter")
        let path = store.searchPathResult(forItemId: "item.measurement.normal.meter")
        let match = rows.first { $0.id == "item.measurement.normal.meter" }
        #expect(match != nil)
        #expect(match?.pathLine == path?.pathLine)
    }

    @Test func searchWithAttachedCatalogIncludesSeedUnits() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        store.attachUnitCatalog(try UnitRegistry.v1Default().allUnits)
        let rows = store.searchItems(query: "fahrenheit")
        #expect(rows.contains { $0.id == "unit:fahrenheit" })
    }

    @Test func converterRouteForSyntheticUnitId() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        store.attachUnitCatalog(try UnitRegistry.v1Default().allUnits)
        let r = store.converterRoute(forTaxonomyItemId: "unit:hour")
        #expect(r?.category == .time)
        #expect(r?.preferredFromUnitId == "hour")
        #expect(r?.resolvedMode == true)
        #expect(r?.mode == .normal)
    }

    @Test func searchExactTagRanksAfterPrefixTitle() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"Measurement","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [
            {
              "id":"item.tag",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Z",
              "description":"d",
              "tags": ["findx"]
            },
            {
              "id":"item.tit",
              "domainId":"measurement",
              "subgenreId":"measurement.normal",
              "name":"Findxen",
              "description":"d"
            }
          ],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
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
        let rows = store.searchItems(query: "findx")
        #expect(rows.count == 2)
        #expect(rows[0].id == "item.tit")
        #expect(rows[1].id == "item.tag")
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

    // MARK: - Taxonomy → converter routing

    @Test func converterRouteUnknownItemReturnsNil() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        #expect(store.converterRoute(forTaxonomyItemId: "item.does.not.exist") == nil)
    }

    @Test func converterRouteNilRegistryReturnsNil() {
        let store = AppTaxonomyStore(injectedRegistry: nil, loadFailureMessage: "x")
        #expect(store.converterRoute(forTaxonomyItemId: "item.measurement.normal.meter") == nil)
    }

    @Test func converterRouteBundledMeter() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let r = store.converterRoute(forTaxonomyItemId: "item.measurement.normal.meter")
        #expect(r?.category == .length)
        #expect(r?.mode == .normal)
        #expect(r?.preferredFromUnitId == "meter")
        #expect(r?.resolvedCategory == true)
        #expect(r?.resolvedMode == true)
        #expect(r?.hasConverterUnitMapping == true)
    }

    @Test func converterRouteSubgenreMapsToAbsurdMode() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let r = store.converterRoute(forTaxonomyItemId: "item.measurement.absurd.elephant")
        #expect(r?.mode == .absurd)
        #expect(r?.resolvedMode == true)
    }

    @Test func converterRouteLifestyleItemHasNoNavModeButUnitMapping() throws {
        let reg = try TaxonomyRegistry()
        let store = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let r = store.converterRoute(forTaxonomyItemId: "item.lifestyle.time.coffee-break")
        #expect(r?.category == .time)
        #expect(r?.resolvedMode == false)
        #expect(r?.preferredFromUnitId == "coffee_break")
    }

    @Test func converterRouteInvalidCategoryRaw() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [{
            "id":"item.bad",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"X",
            "description":"d",
            "unitCategoryRaw":"not_a_category"
          }],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
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
        let r = store.converterRoute(forTaxonomyItemId: "item.bad")
        #expect(r?.category == nil)
        #expect(r?.resolvedCategory == false)
        #expect(r?.mode == .normal)
        #expect(r?.resolvedMode == true)
        #expect(r?.hasAnyResolvableInput == false)
    }

    @Test func converterRoutePartialWithoutUnitMapping() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [{
            "id":"item.partial",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Partial",
            "description":"d",
            "unitCategoryRaw":"length"
          }],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
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
        let r = store.converterRoute(forTaxonomyItemId: "item.partial")
        #expect(r?.category == .length)
        #expect(r?.mode == .normal)
        #expect(r?.preferredFromUnitId == nil)
        #expect(r?.hasConverterUnitMapping == false)
    }

    @Test func applyTaxonomyRouteSetsBundledMeter() {
        ConversionHistory.shared.clearRecentPairs()
        let tax = AppTaxonomyStore()
        let route = tax.converterRoute(forTaxonomyItemId: "item.measurement.normal.meter")
        #expect(route != nil)
        let vm = ConverterViewModel(taxonomy: tax)
        vm.applyTaxonomyRoute(route!)
        #expect(vm.selectedCategory == .length)
        #expect(vm.selectedMode == .normal)
        #expect(vm.selectedFromUnitID == "meter")
        #expect(vm.selectedToUnitID != vm.selectedFromUnitID)
    }

    @Test func applyTaxonomyRouteCoffeeBreakInfersAbsurdMode() {
        let tax = AppTaxonomyStore()
        let route = tax.converterRoute(forTaxonomyItemId: "item.lifestyle.time.coffee-break")
        #expect(route != nil)
        let vm = ConverterViewModel(taxonomy: tax)
        vm.applyTaxonomyRoute(route!)
        #expect(vm.selectedCategory == .time)
        #expect(vm.selectedMode == .absurd)
        #expect(vm.selectedFromUnitID == "coffee_break")
    }

    @Test func applyTaxonomyRouteInvalidUnitIdFallsBackToDefaults() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [{
            "id":"item.fakeunit",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Bad",
            "description":"d",
            "unitCategoryRaw":"length",
            "converterUnitId":"not_in_registry_xyz"
          }],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
            "modes": [
              {"modeRaw":"normal","subgenreId":"measurement.normal"},
              {"modeRaw":"absurd","subgenreId":"measurement.absurd"},
              {"modeRaw":"custom","subgenreId":"measurement.custom"}
            ]
          }
        }
        """
        let reg = try TaxonomyRegistry(jsonData: Data(json.utf8))
        let tax = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let route = tax.converterRoute(forTaxonomyItemId: "item.fakeunit")
        #expect(route?.preferredFromUnitId == "not_in_registry_xyz")
        let vm = ConverterViewModel(taxonomy: tax)
        vm.applyTaxonomyRoute(route!)
        #expect(vm.selectedCategory == .length)
        #expect(vm.selectedMode == .normal)
        #expect(vm.selectedFromUnitID != "not_in_registry_xyz")
    }

    @Test func applyTaxonomyRoutePartialSetsCategoryModeAndDefaultPair() throws {
        let json = """
        {
          "domains": [{"id":"measurement","name":"M","description":"d"}],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"}
          ],
          "items": [{
            "id":"item.partial",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Partial",
            "description":"d",
            "unitCategoryRaw":"length"
          }],
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [{"unitCategoryRaw":"length"}],
            "modes": [
              {"modeRaw":"normal","subgenreId":"measurement.normal"},
              {"modeRaw":"absurd","subgenreId":"measurement.absurd"},
              {"modeRaw":"custom","subgenreId":"measurement.custom"}
            ]
          }
        }
        """
        let reg = try TaxonomyRegistry(jsonData: Data(json.utf8))
        let tax = AppTaxonomyStore(injectedRegistry: reg, loadFailureMessage: nil)
        let route = tax.converterRoute(forTaxonomyItemId: "item.partial")!
        ConversionHistory.shared.clearRecentPairs()
        let vm = ConverterViewModel(taxonomy: tax)
        vm.applyTaxonomyRoute(route)
        #expect(vm.selectedCategory == .length)
        #expect(vm.selectedMode == .normal)
        #expect(vm.selectedFromUnitID == "meter")
        #expect(vm.selectedToUnitID == "kilometer")
    }
}
