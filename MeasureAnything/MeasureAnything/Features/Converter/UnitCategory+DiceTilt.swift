import Foundation
import MeasureAnythingCore

extension UnitCategory {
    /// Resting Z-rotation (degrees) for the absurd dice before each roll spin.
    ///
    /// New categories added to `UnitCategory` should get an explicit value here when possible.
    /// Until then, `@unknown default` picks a stable tilt from the category’s `rawValue` so the UI
    /// still looks intentional rather than identical across categories.
    var converterDiceRestDegrees: Double {
        let base: Double
        switch self {
        case .length:      base = 75
        case .mass:        base = 45
        case .time:        base = 15
        case .temperature: base = 60
        case .volume:      base = 30
        @unknown default:  base = deterministicDiceTilt(forRawCategory: rawValue)
        }
        return base + Double.random(in: -5...5)
    }
}

private func deterministicDiceTilt(forRawCategory raw: String) -> Double {
    let presets: [Double] = [12, 18, 22, 28, 33, 40, 48, 55, 62]
    var h = 2_166_452_345
    for byte in raw.utf8 {
        h = h &* 16_777_619 &+ Int(byte)
    }
    let idx = abs(h) % presets.count
    return presets[idx]
}
