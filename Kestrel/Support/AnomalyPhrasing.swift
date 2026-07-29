import Foundation

/// Risk-communication layer: turn numbers into honest, *non-predictive*
/// language. Everything here describes the present ("right now", "so far"),
/// never the future, and always hedges ("about", "unusually").
enum AnomalyPhrasing {

    /// One-line interpretation for a station's detail view.
    static func interpretation(for a: Anomaly, fahrenheit: Bool) -> String {
        guard a.z != nil else {
            return "Not enough comparable history yet to judge how unusual this is."
        }
        let mag = TempFormat.delta(a.deltaC, fahrenheit: fahrenheit)
        let dir = a.deltaC >= 0 ? "warmer" : "cooler"
        let hourWord = DiurnalAnalysis.partOfDay(for: a.updatedAt)

        if a.tier == .normal {
            return "\(a.station.city) is tracking close to its usual \(hourWord) rhythm right now."
        }
        var s = "Right now \(a.station.city) is \(mag) \(dir) than a typical \(hourWord) lately"
        if let p = a.percentile {
            s += " — \(dir) than about \(percentText(p, warmer: a.deltaC >= 0)) of comparable recent hours."
        } else {
            s += "."
        }
        return s
    }

    /// Short qualifier for the row ("unusually warm for this hour").
    static func rowQualifier(for a: Anomaly) -> String {
        guard a.z != nil, a.tier != .normal else { return "within its usual rhythm" }
        let dir = a.deltaC >= 0 ? "warm" : "cool"
        return "unusually \(dir) for this hour"
    }

    /// Compact, non-truncating qualifier for the radar row.
    static func rowQualifierShort(for a: Anomaly) -> String {
        guard a.z != nil else { return "gathering history" }
        guard a.tier != .normal else { return "within rhythm" }
        return a.deltaC >= 0 ? "unusually warm" : "unusually cool"
    }

    /// The "so what?" — plain meaning + how notable this reading is. Lets a
    /// user act with clear eyes instead of decoding a sigma value.
    static func meaning(for a: Anomaly) -> String {
        guard a.z != nil else {
            return "Kestrel needs a little more history here before it can say how unusual this is."
        }
        switch a.tier {
        case .normal:
            return "Nothing to flag — \(a.station.city) is behaving about as expected for this time of day."
        case .notable:
            return "Worth a glance. This is outside \(a.station.city)'s usual range for this hour, though it does happen now and then."
        case .high:
            return "Clearly unusual. \(a.station.city) is well outside its normal range for this hour right now."
        case .extreme:
            return "Rare. \(a.station.city) is far outside anything typical for this hour in its recent history."
        }
    }

    private static func percentText(_ p: Double, warmer: Bool) -> String {
        // Express as "the top X%" flavour without over-precision.
        let pct = warmer ? p : (1 - p)
        return "\(Int((pct * 100).rounded()))%"
    }

    /// How the baseline was formed — surfaced so the method is never hidden.
    static func baselineNote(for a: Anomaly) -> String {
        if a.usedDiurnal {
            return "Compared against \(a.comparableCount) readings from the same time of day over recent days."
        }
        return "Compared against the \(a.comparableCount) most recent hourly readings (not enough same-hour history yet)."
    }
}
