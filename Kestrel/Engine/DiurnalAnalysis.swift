import Foundation

/// The atmospheric-science + statistics layer on top of the ported z-score.
///
/// Motivation (meteorology): comparing the current temperature against the
/// last N *raw* hourly readings conflates the diurnal cycle — 20 °C at 2 a.m.
/// is a genuine anomaly, at 2 p.m. it is ordinary. So we build the baseline
/// from readings at the **same hour of day** across prior days, which removes
/// the day/night swing and leaves the honest signal: is it unusual *for this
/// hour*?
enum DiurnalAnalysis {

    private static var utcCalendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Temperatures from prior readings whose hour-of-day is within
    /// ±`windowHours` of `now`, oldest → newest. Readings from the last
    /// 30 minutes are excluded so "now" never leaks into its own baseline.
    static func sameHourBaseline(history: [Reading],
                                 now: Date,
                                 windowHours: Int = 1) -> [Double] {
        let cal = utcCalendar
        let targetHour = cal.component(.hour, from: now)
        let cutoff = now.addingTimeInterval(-30 * 60)
        return history
            .filter { $0.timestamp <= cutoff }
            .filter { circularHourDistance(cal.component(.hour, from: $0.timestamp), targetHour) <= windowHours }
            .sorted { $0.timestamp < $1.timestamp }
            .map { $0.temperatureC }
    }

    /// Shortest distance between two hours on a 24-hour clock (so 23 and 1
    /// are 2 apart, not 22).
    static func circularHourDistance(_ a: Int, _ b: Int) -> Int {
        let d = abs(a - b) % 24
        return min(d, 24 - d)
    }

    /// Empirical percentile of `value` within `sample`, in 0...1, using the
    /// mid-rank convention for ties. Distribution-free — it makes no normality
    /// assumption, which is the honest complement to the parametric z-score.
    static func percentile(of value: Double, in sample: [Double]) -> Double? {
        guard !sample.isEmpty else { return nil }
        let below = sample.reduce(0) { $0 + ($1 < value ? 1 : 0) }
        let equal = sample.reduce(0) { $0 + ($1 == value ? 1 : 0) }
        return (Double(below) + Double(equal) / 2.0) / Double(sample.count)
    }

    /// A human label for the local hour a reading represents, e.g. "early
    /// morning". Used only for calibrated, non-predictive phrasing.
    static func partOfDay(for date: Date, timeZone: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        switch cal.component(.hour, from: date) {
        case 5..<8:   return "early morning"
        case 8..<11:  return "morning"
        case 11..<14: return "midday"
        case 14..<17: return "afternoon"
        case 17..<20: return "evening"
        case 20..<23: return "night"
        default:      return "overnight"
        }
    }
}
