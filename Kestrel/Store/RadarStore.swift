import Foundation
import Observation

/// Orchestrates the radar: holds the user's watched stations, fetches each
/// station's snapshot, scores it through `AnomalyEngine`, and publishes a
/// ranked list. All state lives on the main actor; all work is on-device.
@MainActor
@Observable
final class RadarStore {
    private(set) var anomalies: [Anomaly] = []
    private(set) var isLoading = false
    var errorMessage: String?
    private(set) var lastUpdated: Date?

    /// ICAOs the user is watching (persisted).
    private(set) var watched: [String]

    /// Preferred temperature unit for display.
    var useFahrenheit: Bool {
        didSet { defaults.set(useFahrenheit, forKey: Keys.fahrenheit) }
    }

    private let service: WeatherService
    private let defaults: UserDefaults

    private enum Keys {
        static let watched = "kestrel.watched"
        static let fahrenheit = "kestrel.useFahrenheit"
    }

    init(service: WeatherService = WeatherService(), defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
        self.watched = defaults.stringArray(forKey: Keys.watched) ?? StationCatalog.defaultWatch
        self.useFahrenheit = defaults.bool(forKey: Keys.fahrenheit)
    }

    var watchedStations: [Station] {
        watched.compactMap { StationCatalog.station(icao: $0) }
    }

    func isWatching(_ icao: String) -> Bool { watched.contains(icao) }

    func toggleWatch(_ icao: String) {
        if let idx = watched.firstIndex(of: icao) {
            watched.remove(at: idx)
            anomalies.removeAll { $0.station.icao == icao }
        } else {
            watched.append(icao)
        }
        defaults.set(watched, forKey: Keys.watched)
    }

    /// Fetch + score every watched station, concurrently.
    func refresh() async {
        guard !watchedStations.isEmpty else {
            anomalies = []
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let stations = watchedStations
        var results: [Anomaly] = []
        var failures = 0

        await withTaskGroup(of: Anomaly?.self) { group in
            for station in stations {
                group.addTask { [service] in
                    await Self.score(station: station, service: service)
                }
            }
            for await result in group {
                if let result { results.append(result) } else { failures += 1 }
            }
        }

        // Rank: strongest anomaly first, then by confidence.
        results.sort { lhs, rhs in
            let l = abs(lhs.z ?? 0), r = abs(rhs.z ?? 0)
            if l != r { return l > r }
            return lhs.confidence > rhs.confidence
        }

        anomalies = results
        lastUpdated = Date()
        if results.isEmpty && failures > 0 {
            errorMessage = "Couldn't reach the weather service. Pull to try again."
        }
    }

    /// Pure scoring pipeline for one station (runs off the main actor).
    nonisolated private static func score(station: Station,
                                          service: WeatherService) async -> Anomaly? {
        guard let snap = try? await service.snapshot(for: station) else { return nil }
        guard AnomalyEngine.validate(temperatureC: snap.currentTempC).isValid else { return nil }

        let zResult = AnomalyEngine.zScore(readings: snap.baseline, current: snap.currentTempC)
        let cross = AnomalyEngine.crossValidate(primaryC: snap.currentTempC,
                                                secondaryC: snap.metarTempC)
        let deltaC: Double = {
            guard let high = snap.forecastHighC else { return 0 }
            return abs(snap.currentTempC - high)
        }()
        let conf = AnomalyEngine.confidence(
            zScore: zResult?.z,
            deltaC: deltaC,
            crossValidation: cross,
            reportAgeMinutes: snap.reportAgeMinutes,
            consensus: nil
        )

        return Anomaly(
            station: station,
            currentTempC: snap.currentTempC,
            baselineMeanC: zResult?.weightedMean ?? snap.currentTempC,
            forecastHighC: snap.forecastHighC,
            z: zResult?.z,
            confidence: conf.composite,
            crossValidation: cross.label,
            updatedAt: Date()
        )
    }
}
