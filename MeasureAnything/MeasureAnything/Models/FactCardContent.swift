import Foundation

struct FactCardContent: Codable {
    let cards: [String: FactCardEntry]
}

struct FactCardEntry: Codable {
    let valueHeadline: String
    let valueDisplay: String
    let comparisons: [FactCardComparison]
}

struct FactCardComparison: Codable {
    let targetUnitID: String
    let template: String
}
