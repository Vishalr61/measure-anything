import Foundation

/// Loads normal units shipped as JSON resources.
///
/// This is the complement to `AbsurdUnitStore`:
/// - normal units live in `normal_<category>.json`
/// - absurd units continue to live in `<category>.json`
public struct NormalUnitStore: Sendable {
    public enum StoreError: Error, LocalizedError, Equatable {
        case resourceNotFound(name: String, ext: String)
        case decodeFailed(category: UnitCategory, underlying: String)
        case invalidUnit(category: UnitCategory, id: String, underlying: String)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name, let ext):
                "Normal units resource not found: \(name).\(ext)"
            case .decodeFailed(let category, let underlying):
                "Failed to decode normal units for \(category.rawValue): \(underlying)"
            case .invalidUnit(let category, let id, let underlying):
                "Invalid normal unit '\(id)' for \(category.rawValue): \(underlying)"
            }
        }
    }

    public let bundle: Bundle
    public let decoder: JSONDecoder

    public init(bundle: Bundle = AbsurdUnitStore.defaultBundle, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    public func loadAll() throws -> [UnitDefinition] {
        var units: [UnitDefinition] = []
        for category in UnitCategory.allCases {
            units.append(contentsOf: try load(category: category))
        }
        return units
    }

    public func load(category: UnitCategory) throws -> [UnitDefinition] {
        let resourceName = "normal_\(category.rawValue)"
        let resourceExt = "json"
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExt) else {
            throw StoreError.resourceNotFound(name: resourceName, ext: resourceExt)
        }

        do {
            let data = try Data(contentsOf: url)
            let decoded = try decoder.decode([UnitDefinition].self, from: data)

            // Enforce v1 invariants regardless of JSON correctness.
            var validated: [UnitDefinition] = []
            validated.reserveCapacity(decoded.count)
            for unit in decoded {
                do {
                    var u = unit
                    u.kind = .normal
                    u.category = category
                    // Temperature normals are `.temperature`; others are `.multiplicative`.
                    if category == .temperature {
                        u.conversionStyle = .temperature
                    } else {
                        u.conversionStyle = .multiplicative
                    }
                    try u.validate()
                    validated.append(u)
                } catch {
                    throw StoreError.invalidUnit(category: category, id: unit.id, underlying: String(describing: error))
                }
            }
            return validated
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.decodeFailed(category: category, underlying: String(describing: error))
        }
    }
}

