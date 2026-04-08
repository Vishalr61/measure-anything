import XCTest
import MeasureAnythingTaxonomy

final class TaxonomyRegistryTests: XCTestCase {
    func testBundledRegistryLoadsAndValidates() throws {
        let registry = try TaxonomyRegistry()
        XCTAssertEqual(registry.domains.count, 2)
        XCTAssertFalse(registry.subgenres.isEmpty)
        XCTAssertFalse(registry.items.isEmpty)
        XCTAssertNotNil(registry.domainById["measurement"])
        XCTAssertNotNil(registry.subgenreById["measurement.normal"])
        let meter = registry.itemById["item.measurement.normal.meter"]
        XCTAssertEqual(meter?.domainId, "measurement")
        XCTAssertEqual(meter?.subgenreId, "measurement.normal")
        XCTAssertEqual(registry.converterNavigation?.measurementDomainId, "measurement")
        XCTAssertEqual(registry.converterNavigation?.categories.count, 5)
        XCTAssertEqual(registry.converterNavigation?.modes.count, 3)
    }

    func testInitFromJsonData() throws {
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
        XCTAssertEqual(reg.domains.count, 1)
        XCTAssertEqual(reg.subgenreById["measurement.normal"]?.name, "Normal units")
    }
}
