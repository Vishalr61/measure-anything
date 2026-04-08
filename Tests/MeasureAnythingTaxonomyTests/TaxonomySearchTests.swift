import XCTest
import MeasureAnythingCore
import MeasureAnythingTaxonomy

final class TaxonomySearchTests: XCTestCase {
    private func minimalBundleJSON(extraItems: String) -> String {
        """
        {
          "domains": [
            {"id":"measurement","name":"Measurement","description":"m"},
            {"id":"lifestyle","name":"Lifestyle","description":"l"}
          ],
          "subgenres": [
            {"id":"measurement.normal","domainId":"measurement","name":"Normal","description":"n"},
            {"id":"measurement.absurd","domainId":"measurement","name":"Absurd","description":"a"},
            {"id":"measurement.custom","domainId":"measurement","name":"Custom","description":"c"},
            {"id":"lifestyle.blocks","domainId":"lifestyle","name":"Blocks","description":"b"}
          ],
          "items": \(extraItems),
          "converterNavigation": {
            "measurementDomainId": "measurement",
            "categories": [
              {"unitCategoryRaw":"length"},
              {"unitCategoryRaw":"mass"}
            ],
            "modes": [
              {"modeRaw":"normal","subgenreId":"measurement.normal"},
              {"modeRaw":"absurd","subgenreId":"measurement.absurd"},
              {"modeRaw":"custom","subgenreId":"measurement.custom"}
            ]
          }
        }
        """
    }

    func testBlankQueryReturnsEmpty() throws {
        let json = minimalBundleJSON(extraItems: "[]")
        let reg = try TaxonomyRegistry(jsonData: Data(json.utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        XCTAssertTrue(index.search(query: "   ").isEmpty)
    }

    func testExactTitleRanksBeforeExactSynonym() throws {
        let items = """
        [
          {
            "id":"item.b",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Zebra",
            "description":"d",
            "synonyms": ["qqqqtoken"]
          },
          {
            "id":"item.a",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Qqqqtoken",
            "description":"d"
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let rows = index.search(query: "qqqqtoken")
        XCTAssertEqual(rows.map(\.id), ["item.a", "item.b"])
    }

    func testPathFromSearchMatchesPathLookup() throws {
        let items = """
        [{
          "id":"item.x",
          "domainId":"measurement",
          "subgenreId":"measurement.normal",
          "name":"Alpha",
          "description":"d",
          "tags":["findz"]
        }]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let rows = index.search(query: "findz")
        XCTAssertEqual(rows.count, 1)
        let path = index.pathResult(forItemId: "item.x")
        XCTAssertEqual(rows[0].pathLine, path?.pathLine)
    }

    func testFilterByDomainId() throws {
        let items = """
        [
          {
            "id":"item.m",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"SharedTag",
            "description":"d",
            "tags":["sharedtag"]
          },
          {
            "id":"item.l",
            "domainId":"lifestyle",
            "subgenreId":"lifestyle.blocks",
            "name":"SharedTag",
            "description":"d",
            "tags":["sharedtag"]
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let all = index.search(query: "sharedtag")
        XCTAssertEqual(all.count, 2)
        let meas = index.search(query: "sharedtag", categoryId: "measurement")
        XCTAssertEqual(meas.count, 1)
        XCTAssertEqual(meas[0].id, "item.m")
    }

    func testFilterBySubcategoryId() throws {
        let items = """
        [
          {
            "id":"item.norm",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Pickme",
            "description":"d",
            "tags":["tok"]
          },
          {
            "id":"item.abs",
            "domainId":"measurement",
            "subgenreId":"measurement.absurd",
            "name":"Pickme",
            "description":"d",
            "tags":["tok"]
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let rows = index.search(query: "tok", subcategoryId: "measurement.absurd")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, "item.abs")
    }

    func testFilterByUnitCategoryRaw() throws {
        let items = """
        [
          {
            "id":"item.len",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"X",
            "description":"d",
            "tags":["zz"],
            "unitCategoryRaw":"length"
          },
          {
            "id":"item.mass",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"X",
            "description":"d",
            "tags":["zz"],
            "unitCategoryRaw":"mass"
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let rows = index.search(query: "zz", unitCategoryRaw: "length")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, "item.len")
    }

    func testSyntheticUnitsMergedAndDedupedByConverterId() throws {
        let items = """
        [{
          "id":"item.meter.row",
          "domainId":"measurement",
          "subgenreId":"measurement.normal",
          "name":"Meter",
          "description":"d",
          "unitCategoryRaw":"length",
          "converterUnitId":"meter"
        }]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let meterDef = try XCTUnwrap(SeedNormalUnits.length.first { $0.id == "meter" })
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [meterDef])
        let byId = Set(index.search(query: "meter").map(\.id))
        XCTAssertTrue(byId.contains("item.meter.row"))
        XCTAssertFalse(byId.contains("unit:meter"))
    }

    func testTagContainsRequiresAtLeastTwoQueryCharacters() throws {
        let items = """
        [{
          "id":"item.t",
          "domainId":"measurement",
          "subgenreId":"measurement.normal",
          "name":"Z",
          "description":"d",
          "tags":["length"]
        }]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        XCTAssertFalse(index.search(query: "l").isEmpty)
        XCTAssertFalse(index.search(query: "ng").isEmpty)
    }

    func testBrowseReturnsFilteredTitleSorted() throws {
        let items = """
        [
          {
            "id":"item.z",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Zebra",
            "description":"d",
            "tags":["t"]
          },
          {
            "id":"item.a",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"Alpha",
            "description":"d",
            "tags":["t"]
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let sections = index.browseSections(inDomain: "measurement")
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].id, "measurement.all")
        XCTAssertEqual(sections[0].items.map(\.id), ["item.a", "item.z"])
        let flat = index.browse()
        XCTAssertEqual(flat.map(\.id), ["item.a", "item.z"])
    }

    func testBrowseSectionsSplitBySubgenre() throws {
        let items = """
        [
          {
            "id":"item.norm",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"N",
            "description":"d"
          },
          {
            "id":"item.abs",
            "domainId":"measurement",
            "subgenreId":"measurement.absurd",
            "name":"A",
            "description":"d"
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let sections = index.browseSections(inDomain: "measurement")
        XCTAssertEqual(sections.count, 2)
        let ids = Set(sections.map(\.id))
        XCTAssertEqual(ids, Set(["measurement.sub.measurement.normal", "measurement.sub.measurement.absurd"]))
    }

    func testBrowseDomainsAggregatesCounts() throws {
        let items = """
        [
          {"id":"a","domainId":"measurement","subgenreId":"measurement.normal","name":"A","description":"d"},
          {"id":"b","domainId":"measurement","subgenreId":"measurement.normal","name":"B","description":"d"},
          {"id":"c","domainId":"lifestyle","subgenreId":"lifestyle.blocks","name":"C","description":"d"}
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let domains = index.browseDomains()
        XCTAssertEqual(domains.count, 2)
        let m = domains.first { $0.id == "measurement" }
        XCTAssertEqual(m?.itemCount, 2)
        XCTAssertEqual(m?.subtitle, "Normal")
        let life = domains.first { $0.id == "lifestyle" }
        XCTAssertEqual(life?.itemCount, 1)
        XCTAssertEqual(life?.subtitle, "Blocks")
    }

    func testBrowseDomainsSubtitleListsTopSubgenres() throws {
        let items = """
        [
          {"id":"n1","domainId":"measurement","subgenreId":"measurement.normal","name":"A","description":"d"},
          {"id":"n2","domainId":"measurement","subgenreId":"measurement.normal","name":"B","description":"d"},
          {"id":"n3","domainId":"measurement","subgenreId":"measurement.normal","name":"C","description":"d"},
          {"id":"ab","domainId":"measurement","subgenreId":"measurement.absurd","name":"Z","description":"d"}
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let sub = index.browseDomains().first { $0.id == "measurement" }?.subtitle
        XCTAssertEqual(sub, "Normal · Absurd")
    }

    func testBrowseDomainsSubtitleUsesUnitCategoriesWhenSingleSubgenre() throws {
        let items = """
        [
          {"id":"len","domainId":"measurement","subgenreId":"measurement.normal","name":"L","description":"d","unitCategoryRaw":"length"},
          {"id":"mass","domainId":"measurement","subgenreId":"measurement.normal","name":"M","description":"d","unitCategoryRaw":"mass"}
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let sub = index.browseDomains().first { $0.id == "measurement" }?.subtitle
        XCTAssertEqual(sub, "Length · Mass")
    }

    func testBrowseSingleSubgenreMultipleUnitCategoriesGroupsByCategory() throws {
        let items = """
        [
          {"id":"len","domainId":"measurement","subgenreId":"measurement.normal","name":"L","description":"d","unitCategoryRaw":"length"},
          {"id":"mass","domainId":"measurement","subgenreId":"measurement.normal","name":"M","description":"d","unitCategoryRaw":"mass"}
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let sections = index.browseSections(inDomain: "measurement")
        XCTAssertEqual(sections.count, 2)
        let titles = Set(sections.map(\.title))
        XCTAssertEqual(titles, Set(["Length", "Mass"]))
    }

    func testBrowseRespectsDomainFilter() throws {
        let items = """
        [
          {
            "id":"item.m",
            "domainId":"measurement",
            "subgenreId":"measurement.normal",
            "name":"M",
            "description":"d"
          },
          {
            "id":"item.l",
            "domainId":"lifestyle",
            "subgenreId":"lifestyle.blocks",
            "name":"L",
            "description":"d"
          }
        ]
        """
        let reg = try TaxonomyRegistry(jsonData: Data(minimalBundleJSON(extraItems: items).utf8))
        let index = TaxonomySearchIndex(registry: reg, unitCatalog: [])
        let rows = index.browse(categoryId: "lifestyle")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].id, "item.l")
    }
}
