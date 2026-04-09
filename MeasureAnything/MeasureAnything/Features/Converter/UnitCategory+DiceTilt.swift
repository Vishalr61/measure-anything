import Foundation
import MeasureAnythingCore

extension UnitCategory {
    /// Resting Z-rotation (degrees) for the absurd dice before each roll spin.
    ///
    /// New categories added to `UnitCategory` should get an explicit value here when possible.
    /// Until then, `@unknown default` picks a stable tilt from the category’s `rawValue` so the UI
    /// still looks intentional rather than identical across categories.
    var converterDiceRestDegrees: Double {
        switch self {
        case .length: return 75
        case .mass: return 45
        case .time: return 15
        case .temperature: return 60
        case .volume: return 30
        @unknown default:
            return deterministicDiceTilt(forRawCategory: rawValue)
        }
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
