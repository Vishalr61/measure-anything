import Foundation

/// A unified registry of units available to the conversion engine.
///
/// v1 composition:
/// - Normal units: built-in (`SeedNormalUnits`)
/// - Absurd units: shipped JSON (`AbsurdUnitStore`)
/// - Custom units: intentionally not included yet (SwiftData later)
public struct UnitRegistry: Sendable {
    public enum RegistryError: Error, LocalizedError, Equatable {
        case duplicateUnitID(String)
        case unknownUnitID(String)
        case categoryMismatch(from: String, to: String)

        public var errorDescription: String? {
            switch self {
            case .duplicateUnitID(let id):
                "Duplicate unit id in registry: \(id)"
            case .unknownUnitID(let id):
                "Unknown unit id: \(id)"
            case .categoryMismatch(let from, let to):
                "Cannot convert between different categories (\(from) -> \(to))."
            }
        }
    }

    private var byID: [UnitDefinition.ID: UnitDefinition]

    public init(units: [UnitDefinition]) throws {
        var map: [UnitDefinition.ID: UnitDefinition] = [:]
        map.reserveCapacity(units.count)
        for unit in units {
            if map[unit.id] != nil {
                throw RegistryError.duplicateUnitID(unit.id)
            }
            map[unit.id] = unit
        }
        self.byID = map
    }

    public static func v1Default(absurdStore: AbsurdUnitStore = AbsurdUnitStore()) throws -> UnitRegistry {
        let normals = SeedNormalUnits.all
        let absurd = try absurdStore.loadAll()
        return try UnitRegistry(units: normals + absurd)
    }

    public func unit(id: UnitDefinition.ID) throws -> UnitDefinition {
        guard let unit = byID[id] else { throw RegistryError.unknownUnitID(id) }
        return unit
    }

    public func units(in category: UnitCategory, includeKinds: Set<UnitKind> = Set(UnitKind.allCases)) -> [UnitDefinition] {
        byID.values
            .filter { $0.category == category && includeKinds.contains($0.kind) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Mode behavior helper:
    /// - Normal: normal only
    /// - Absurd: normal + absurd
    /// - Custom: normal + custom (custom units added later)
    public enum Mode: String, CaseIterable, Codable, Hashable, Sendable {
        case normal
        case absurd
        case custom

        public var includedKinds: Set<UnitKind> {
            switch self {
            case .normal: [.normal]
            case .absurd: [.normal, .absurd]
            case .custom: [.normal, .custom]
            }
        }
    }
}

