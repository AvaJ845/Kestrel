import Foundation

/// A weather station Kestrel watches — resolved from a compact built-in
/// catalog of major-city airports (ICAO + coordinates). Ported from
/// Kestrel's `CITY_ICAO_LOOKUP`.
struct Station: Identifiable, Hashable, Codable, Sendable {
    let icao: String
    let city: String
    let latitude: Double
    let longitude: Double

    var id: String { icao }

    /// "Phoenix (KPHX)"
    var displayName: String { "\(city)" }
}

/// A single temperature observation used for the rolling anomaly baseline.
struct Reading: Hashable, Codable, Sendable {
    let temperatureC: Double
    let timestamp: Date
}
