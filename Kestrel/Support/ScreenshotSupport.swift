#if DEBUG
import Foundation

/// Deterministic sample data for headless App Store screenshots
/// (`simctl launch … -shotroot <screen>`). DEBUG-only.
extension Anomaly {
    /// A vivid, legible anomaly for the detail-screen shot: Denver running
    /// well below its usual afternoon rhythm.
    static var sampleDenver: Anomaly {
        let baseline = 17.4
        // 24 hours wiggling around the baseline, then a clear drop to "now".
        let series: [Double] = [
            16.8, 17.1, 17.6, 18.0, 18.4, 18.1, 17.5, 17.0, 16.6, 16.9, 17.3, 17.8,
            18.2, 18.6, 18.3, 17.7, 17.2, 16.8, 16.4, 15.6, 14.7, 13.8, 12.9, 12.1,
        ]
        return Anomaly(
            station: Station(icao: "KDEN", city: "Denver", latitude: 39.8561, longitude: -104.674),
            currentTempC: 12.1,
            baselineMeanC: baseline,
            forecastHighC: 19.0,
            z: -2.4,
            confidence: 78,
            crossValidation: "verified",
            updatedAt: Date(),
            percentile: 0.04,
            bandLowC: baseline - 2.1,
            bandHighC: baseline + 2.1,
            comparableCount: 7,
            usedDiurnal: true,
            sparkline: series
        )
    }
}
#endif
