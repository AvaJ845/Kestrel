import Foundation

/// Everything Kestrel measures for one station, fetched from free,
/// no-key public sources: Open-Meteo (current temp, timestamped hourly
/// history, daily-high forecast) and aviation METAR (an independent sensor
/// used only to cross-validate). No account, no key, no personal data leaves
/// the device.
struct StationSnapshot: Sendable {
    let currentTempC: Double
    let currentTime: Date
    /// Timestamped hourly readings, oldest → newest (UTC).
    let hourly: [Reading]
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

    /// - Parameter pastDays: how many days of hourly history to pull for the
    ///   baseline (7 free · 30 Pro — a steadier same-hour sample).
    func snapshot(for station: Station, pastDays: Int = 7) async throws -> StationSnapshot {
        async let meteo = fetchOpenMeteo(station, pastDays: pastDays)
        // METAR is best-effort: a cross-validation bonus, never a hard dependency.
        let metar = try? await fetchMetarTemp(icao: station.icao)
        let m = try await meteo
        return StationSnapshot(
            currentTempC: m.current,
            currentTime: m.currentTime,
            hourly: m.hourly,
            forecastHighC: m.forecastHigh,
            metarTempC: metar,
            reportAgeMinutes: m.ageMinutes
        )
    }

    // MARK: - Open-Meteo

    private struct MeteoResult {
        let current: Double
        let currentTime: Date
        let hourly: [Reading]
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

    private func fetchOpenMeteo(_ station: Station, pastDays: Int) async throws -> MeteoResult {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(station.latitude)),
            .init(name: "longitude", value: String(station.longitude)),
            .init(name: "current", value: "temperature_2m"),
            .init(name: "hourly", value: "temperature_2m"),
            .init(name: "daily", value: "temperature_2m_max"),
            .init(name: "past_days", value: String(max(2, min(92, pastDays)))),
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

        let now = Date()
        let currentTime = parseHour(decoded.current.time) ?? now

        // Build the timestamped hourly series, keeping readings up to "now".
        var hourly: [Reading] = []
        for (idx, timeStr) in decoded.hourly.time.enumerated() {
            guard idx < decoded.hourly.temperature_2m.count,
                  let temp = decoded.hourly.temperature_2m[idx],
                  let t = parseHour(timeStr),
                  t <= currentTime.addingTimeInterval(3600) else { continue }
            hourly.append(Reading(temperatureC: temp, timestamp: t))
        }

        let ageMinutes = max(0, Int(now.timeIntervalSince(currentTime) / 60))

        return MeteoResult(
            current: decoded.current.temperature_2m,
            currentTime: currentTime,
            hourly: hourly,
            forecastHigh: decoded.daily.temperature_2m_max.first ?? nil,
            ageMinutes: ageMinutes
        )
    }

    /// Open-Meteo returns "yyyy-MM-dd'T'HH:mm" (no seconds, no zone; UTC here).
    private func parseHour(_ raw: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(identifier: "UTC")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm"
        if let d = df.date(from: raw) { return d }
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df.date(from: raw)
    }

    /// Today's daily-high forecast from a single named model — used by Pro's
    /// multi-model agreement check. Best-effort; returns nil on any failure.
    func dailyHigh(for station: Station, model: String) async -> Double? {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude", value: String(station.latitude)),
            .init(name: "longitude", value: String(station.longitude)),
            .init(name: "daily", value: "temperature_2m_max"),
            .init(name: "forecast_days", value: "1"),
            .init(name: "timezone", value: "UTC"),
            .init(name: "temperature_unit", value: "celsius"),
            .init(name: "models", value: model),
        ]
        guard let url = comps.url,
              let (data, response) = try? await session.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        struct R: Decodable { struct D: Decodable { let temperature_2m_max: [Double?] }; let daily: D }
        guard let decoded = try? JSONDecoder().decode(R.self, from: data) else { return nil }
        return decoded.daily.temperature_2m_max.first ?? nil
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
