import Foundation

/// Loads absurd units shipped as JSON resources.
public struct AbsurdUnitStore: Sendable {
    public enum StoreError: Error, LocalizedError, Equatable {
        case resourceNotFound(name: String, ext: String)
        case decodeFailed(category: UnitCategory, underlying: String)
        case invalidUnit(category: UnitCategory, id: String, underlying: String)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound(let name, let ext):
                "Absurd units resource not found: \(name).\(ext)"
            case .decodeFailed(let category, let underlying):
                "Failed to decode absurd units for \(category.rawValue): \(underlying)"
            case .invalidUnit(let category, let id, let underlying):
                "Invalid absurd unit '\(id)' for \(category.rawValue): \(underlying)"
            }
        }
    }

    public let bundle: Bundle
    public let decoder: JSONDecoder

    /// `resourceFolder` is kept for future flexibility (e.g. subfolders),
    /// but v1 uses plain resource names like `length.json`.
    public init(bundle: Bundle = AbsurdUnitStore.defaultBundle, decoder: JSONDecoder = JSONDecoder()) {
        self.bundle = bundle
        self.decoder = decoder
    }

    /// Default bundle selection:
    /// - Swift Package: `Bundle.module` (so tests can load packaged JSON resources)
    /// - App target: `.main`
    public static var defaultBundle: Bundle {
#if SWIFT_PACKAGE
        .module
#else
        .main
#endif
    }

    public func loadAll() throws -> [UnitDefinition] {
        var units: [UnitDefinition] = []
        for category in UnitCategory.allCases where category != .temperature {
            units.append(contentsOf: try load(category: category))
        }
        return units
    }

    public func load(category: UnitCategory) throws -> [UnitDefinition] {
        precondition(category != .temperature, "v1: absurd temperature units are not supported")

        let resourceName = category.rawValue
        let resourceExt = "json"
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExt) else {
            throw StoreError.resourceNotFound(name: resourceName, ext: resourceExt)
        }

        do {
            let data = try Data(contentsOf: url)
            return try decodeAndValidate(data: data, category: category)
        } catch let error as StoreError {
            throw error
        } catch {
            throw StoreError.decodeFailed(category: category, underlying: String(describing: error))
        }
    }

    func decodeAndValidate(data: Data, category: UnitCategory) throws -> [UnitDefinition] {
        let decoded = try decoder.decode([UnitDefinition].self, from: data)

        // Enforce v1 invariants regardless of JSON correctness.
        var validated: [UnitDefinition] = []
        validated.reserveCapacity(decoded.count)

        for unit in decoded {
            do {
                var u = unit
                u.kind = .absurd
                u.category = category
                u.conversionStyle = .multiplicative
                try u.validate()
                validated.append(u)
            } catch {
                throw StoreError.invalidUnit(
                    category: category,
                    id: unit.id,
                    underlying: String(describing: error)
                )
            }
        }
        return validated
    }
}

