import Foundation

/// Everything Kestrel measures for one station, fetched from free,
/// no-key public sources: Open-Meteo (current temp, recent hourly baseline,
/// daily-high forecast) and aviation METAR (an independent sensor used only
/// to cross-validate). No account, no key, no personal data leaves the device.
struct StationSnapshot: Sendable {
    let currentTempC: Double
    /// Recent hourly readings, oldest → newest, for the anomaly baseline.
    let baseline: [Double]
    let forecastHighC: Double?
    /// Independent METAR sensor temp, if available.
    let metarTempC: Double?
    /// Age of the freshest source reading, in minutes.
    let reportAgeMinutes: Int?
}

enum WeatherError: LocalizedError {
    case badResponse
    case decoding

    var errorDescription: String? {
        switch self {
        case .badResponse: return "Couldn't reach the weather service."
        case .decoding: return "Received an unexpected response."
        }
    }
}

actor WeatherService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func snapshot(for station: Station) async throws -> StationSnapshot {
        async let meteo = fetchOpenMeteo(station)
        // METAR is best-effort: a cross-validation bonus, never a hard dependency.
        let metar = try? await fetchMetarTemp(icao: station.icao)
        let m = try await meteo
        return StationSnapshot(
            currentTempC: m.current,
            baseline: m.baseline,
            forecastHighC: m.forecastHigh,
            metarTempC: metar,
            reportAgeMinutes: m.ageMinutes
        )
    }

    // MARK: - Open-Meteo

    private struct MeteoResult {
        let current: Double
        let baseline: [Double]
        let forecastHigh: Double?
        let ageMinutes: Int?
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            let time: String
            let temperature_2m: Double
        }
        struct Hourly: Decodable {
            let time: [String]
            let temperature_2m: [Double?]
        }
        struct Daily: Decodable {
            let temperature_2m_max: [Double?]
        }
        let current: Current
        let hourly: Hourly
        let daily: Daily
    }

    private func fetchOpenMeteo(_ station: Station) async throws -> MeteoResult {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(station.latitude)),
            .init(name: "longitude", value: String(station.longitude)),
            .init(name: "current", value: "temperature_2m"),
            .init(name: "hourly", value: "temperature_2m"),
            .init(name: "daily", value: "temperature_2m_max"),
            .init(name: "past_days", value: "2"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "UTC"),
            .init(name: "temperature_unit", value: "celsius"),
        ]
        guard let url = comps.url else { throw WeatherError.badResponse }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.badResponse
        }
        let decoded: OpenMeteoResponse
        do {
            decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw WeatherError.decoding
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]

        // Build the baseline from hourly readings up to and including "now",
        // keeping only the most recent `historySize` values (oldest → newest).
        let now = Date()
        var series: [Double] = []
        for (idx, timeStr) in decoded.hourly.time.enumerated() {
            guard idx < decoded.hourly.temperature_2m.count,
                  let temp = decoded.hourly.temperature_2m[idx],
                  let t = parseHour(timeStr, formatter: formatter),
                  t <= now.addingTimeInterval(3600) else { continue }
            series.append(temp)
        }
        let baseline = Array(series.suffix(EngineConfig.historySize))

        // Freshness of the current reading.
        let ageMinutes: Int?
        if let currentTime = parseHour(decoded.current.time, formatter: formatter) {
            ageMinutes = max(0, Int(now.timeIntervalSince(currentTime) / 60))
        } else {
            ageMinutes = nil
        }

        return MeteoResult(
            current: decoded.current.temperature_2m,
            baseline: baseline,
            forecastHigh: decoded.daily.temperature_2m_max.first ?? nil,
            ageMinutes: ageMinutes
        )
    }

    /// Open-Meteo returns "yyyy-MM-dd'T'HH:mm" (no seconds, no zone; UTC here).
    private func parseHour(_ raw: String, formatter: ISO8601DateFormatter) -> Date? {
        if let d = formatter.date(from: raw + ":00Z") { return d }
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return df.date(from: raw)
    }

    // MARK: - METAR (cross-validation only)

    private struct MetarRecord: Decodable {
        let temp: Double?
    }

    private func fetchMetarTemp(icao: String) async throws -> Double? {
        var comps = URLComponents(string: "https://aviationweather.gov/api/data/metar")!
        comps.queryItems = [
            .init(name: "ids", value: icao),
            .init(name: "format", value: "json"),
        ]
        guard let url = comps.url else { return nil }
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let records = try JSONDecoder().decode([MetarRecord].self, from: data)
        return records.first?.temp
    }
}
