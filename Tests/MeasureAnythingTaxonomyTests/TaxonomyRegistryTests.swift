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
    }
}
