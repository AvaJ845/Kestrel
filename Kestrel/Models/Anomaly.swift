import Foundation
import SwiftUI

/// The result of scoring one station — how far its current temperature has
/// drifted from its recent rhythm, with the confidence in that reading.
struct Anomaly: Identifiable, Hashable {
    let station: Station
    let currentTempC: Double
    let baselineMeanC: Double
    let forecastHighC: Double?
    let z: Double?
    let confidence: Int
    let crossValidation: String   // "verified" | "unverified" | "divergent"
    let updatedAt: Date

    var id: String { station.icao }

    /// Signed drift from the recent baseline, in °C.
    var deltaC: Double { currentTempC - baselineMeanC }

    var tier: Tier { Tier(z: z) }

    enum Tier: Int, Comparable {
        case normal, notable, high, extreme

        init(z: Double?) {
            guard let z else { self = .normal; return }
            let a = abs(z)
            if a >= 3.0 { self = .extreme }
            else if a >= 2.0 { self = .high }
            else if a >= EngineConfig.zScoreThreshold { self = .notable }
            else { self = .normal }
        }

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }

        var title: String {
            switch self {
            case .normal: return "Within rhythm"
            case .notable: return "Notable"
            case .high: return "High"
            case .extreme: return "Extreme"
            }
        }

        var color: Color {
            switch self {
            case .normal: return .secondary
            case .notable: return .yellow
            case .high: return .orange
            case .extreme: return .red
            }
        }

        var symbol: String {
            switch self {
            case .normal: return "checkmark.circle"
            case .notable: return "dot.radiowaves.left.and.right"
            case .high: return "exclamationmark.triangle"
            case .extreme: return "flame"
            }
        }
    }
}
