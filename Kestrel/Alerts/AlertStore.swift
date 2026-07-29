import Foundation
import Observation

/// Per-station movement alerts. A user long-presses a station and chooses how
/// unusual it must get before Kestrel pings them. This is an *observation*
/// ("it's unusual right now"), never a forecast or a call to action.
@MainActor
@Observable
final class AlertStore {
    enum Sensitivity: String, CaseIterable, Identifiable {
        case notable   // ≥ 1.5σ — "let me know when it's off-rhythm"
        case high      // ≥ 2.0σ — "only clearly unusual"
        case extreme   // ≥ 3.0σ — "only the big ones"

        var id: String { rawValue }

        var minTier: Anomaly.Tier {
            switch self {
            case .notable: return .notable
            case .high: return .high
            case .extreme: return .extreme
            }
        }

        var label: String {
            switch self {
            case .notable: return "Off-rhythm (±1.5σ)"
            case .high: return "Clearly unusual (±2σ)"
            case .extreme: return "Extreme only (±3σ)"
            }
        }
    }

    /// icao → sensitivity.
    private(set) var configs: [String: Sensitivity] = [:]

    private let defaults: UserDefaults
    private let key = "kestrel.alertConfigs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.dictionary(forKey: key) as? [String: String] {
            configs = raw.compactMapValues(Sensitivity.init(rawValue:))
        }
    }

    func isEnabled(_ icao: String) -> Bool { configs[icao] != nil }
    func sensitivity(_ icao: String) -> Sensitivity? { configs[icao] }

    func setAlert(_ icao: String, sensitivity: Sensitivity) {
        configs[icao] = sensitivity
        persist()
    }

    func disable(_ icao: String) {
        configs[icao] = nil
        persist()
    }

    var enabledCount: Int { configs.count }

    private func persist() {
        defaults.set(configs.mapValues(\.rawValue), forKey: key)
    }
}
