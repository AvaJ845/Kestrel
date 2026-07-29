import Foundation
import Observation

/// Orchestrates the radar: holds the user's watched stations, fetches each
/// station's snapshot, scores it through the diurnal + z-score engine, and
/// publishes a ranked list. All state lives on the main actor; all work is
/// on-device.
@MainActor
@Observable
final class RadarStore {
    private(set) var anomalies: [Anomaly] = []
    private(set) var isLoading = false
    var errorMessage: String?
    private(set) var lastUpdated: Date?

    /// Non-nil when a gated action wants the paywall shown.
    var paywallReason: String?

    private(set) var watched: [String]

    var useFahrenheit: Bool {
        didSet { defaults.set(useFahrenheit, forKey: Keys.fahrenheit) }
    }

    /// Pro-adjustable baseline window (days of same-hour history). Free users
    /// are always 7; Pro can choose 7 / 14 / 30 for a steadier read.
    var baselineDays: Int {
        didSet {
            let allowed = [7, 14, 30]
            if !allowed.contains(baselineDays) { baselineDays = 7 }
            defaults.set(baselineDays, forKey: Keys.baselineDays)
        }
    }

    /// The window actually used given the current entitlement.
    var effectiveBaselineDays: Int {
        entitlements.isPro ? baselineDays : FreeTierLimits.baselineDaysFree
    }

    private let service: WeatherService
    private let defaults: UserDefaults
    private let entitlements: EntitlementStore
    let alerts: AlertStore
    let notifications: NotificationManager

    private enum Keys {
        static let watched = "kestrel.watched"
        static let fahrenheit = "kestrel.useFahrenheit"
        static let baselineDays = "kestrel.baselineDays"
    }

    init(service: WeatherService = WeatherService(),
         entitlements: EntitlementStore,
         alerts: AlertStore,
         notifications: NotificationManager,
         defaults: UserDefaults = .standard) {
        self.service = service
        self.entitlements = entitlements
        self.alerts = alerts
        self.notifications = notifications
        self.defaults = defaults
        self.watched = defaults.stringArray(forKey: Keys.watched) ?? StationCatalog.defaultWatch
        self.useFahrenheit = defaults.bool(forKey: Keys.fahrenheit)
        let storedDays = defaults.object(forKey: Keys.baselineDays) as? Int ?? FreeTierLimits.baselineDaysFree
        self.baselineDays = [7, 14, 30].contains(storedDays) ? storedDays : FreeTierLimits.baselineDaysFree
    }

    var watchedStations: [Station] {
        watched.compactMap { StationCatalog.station(icao: $0) }
    }

    var summary: (breaking: Int, total: Int) {
        (anomalies.filter(\.isBreakingRhythm).count, anomalies.count)
    }

    var canAddMoreStations: Bool {
        entitlements.isPro || watched.count < FreeTierLimits.maxStations
    }

    func isWatching(_ icao: String) -> Bool { watched.contains(icao) }

    /// Returns false (and sets `paywallReason`) if a free user is at the cap.
    @discardableResult
    func toggleWatch(_ icao: String) -> Bool {
        if let idx = watched.firstIndex(of: icao) {
            watched.remove(at: idx)
            anomalies.removeAll { $0.station.icao == icao }
            defaults.set(watched, forKey: Keys.watched)
            return true
        }
        guard canAddMoreStations else {
            // Caller decides how to surface this (avoids double-presenting a
            // paywall from both the picker sheet and the radar screen).
            return false
        }
        watched.append(icao)
        defaults.set(watched, forKey: Keys.watched)
        return true
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
        let pastDays = effectiveBaselineDays
        var results: [Anomaly] = []
        var failures = 0

        await withTaskGroup(of: Anomaly?.self) { group in
            for station in stations {
                group.addTask { [service] in
                    await Self.score(station: station, service: service, pastDays: pastDays)
                }
            }
            for await result in group {
                if let result { results.append(result) } else { failures += 1 }
            }
        }

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

        // Honest movement alerts: ping only alert-enabled stations that are
        // currently past the user's chosen sensitivity (and off cooldown).
        if alerts.enabledCount > 0 {
            await notifications.evaluate(anomalies: results, alerts: alerts, fahrenheit: useFahrenheit)
        }
    }

    /// Pro: how much independent weather models agree on today's high — a
    /// data-quality/uncertainty signal, not a Kestrel forecast.
    func loadConsensus(for station: Station) async -> AnomalyEngine.Consensus? {
        async let gfs = service.dailyHigh(for: station, model: "gfs_seamless")
        async let ecmwf = service.dailyHigh(for: station, model: "ecmwf_ifs04")
        async let icon = service.dailyHigh(for: station, model: "icon_seamless")
        let models: [String: Double?] = ["GFS": await gfs, "ECMWF": await ecmwf, "ICON": await icon]
        return AnomalyEngine.consensus(models: models)
    }

    /// Pure scoring pipeline for one station (runs off the main actor).
    nonisolated private static func score(station: Station,
                                          service: WeatherService,
                                          pastDays: Int) async -> Anomaly? {
        guard let snap = try? await service.snapshot(for: station, pastDays: pastDays) else { return nil }
        guard AnomalyEngine.validate(temperatureC: snap.currentTempC).isValid else { return nil }

        // Diurnal (same-hour) baseline is the honest signal; fall back to the
        // most recent raw hourly readings only when we lack comparable hours.
        let diurnal = DiurnalAnalysis.sameHourBaseline(history: snap.hourly, now: snap.currentTime)
        let usedDiurnal = diurnal.count >= 3
        let baseline = usedDiurnal
            ? diurnal
            : Array(snap.hourly.suffix(EngineConfig.historySize).map(\.temperatureC))

        let zResult = AnomalyEngine.zScore(readings: baseline, current: snap.currentTempC)
        let pct = DiurnalAnalysis.percentile(of: snap.currentTempC, in: baseline)
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

        let mean = zResult?.weightedMean ?? snap.currentTempC
        let sd = zResult?.weightedStdDev ?? 0
        let sparkline = Array(snap.hourly.suffix(48).map(\.temperatureC))

        return Anomaly(
            station: station,
            currentTempC: snap.currentTempC,
            baselineMeanC: mean,
            forecastHighC: snap.forecastHighC,
            z: zResult?.z,
            confidence: conf.composite,
            crossValidation: cross.label,
            updatedAt: Date(),
            percentile: pct,
            bandLowC: sd > 0 ? mean - sd : nil,
            bandHighC: sd > 0 ? mean + sd : nil,
            comparableCount: baseline.count,
            usedDiurnal: usedDiurnal,
            sparkline: sparkline
        )
    }
}
