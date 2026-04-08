import Foundation
import SwiftData

/// Saved conversion pair only (no input value, result, or meme toggle).
@Model
final class FavoriteConversion {
    @Attribute(.unique) var id: String
    var categoryRaw: String
    var fromUnitID: String
    var toUnitID: String
    var label: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        categoryRaw: String,
        fromUnitID: String,
        toUnitID: String,
        label: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.categoryRaw = categoryRaw
        self.fromUnitID = fromUnitID
        self.toUnitID = toUnitID
        self.label = label
        self.createdAt = createdAt
    }
}
