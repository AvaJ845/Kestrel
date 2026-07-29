import Foundation

/// Compact built-in station catalog — a curated subset of Kestrel's
/// `CITY_ICAO_LOOKUP` (one major airport per US state/metro). Enough to
/// make the radar meaningful without shipping a giant table; the app only
/// polls stations the user is watching.
enum StationCatalog {
    static let all: [Station] = [
        Station(icao: "PANC", city: "Anchorage",     latitude: 61.1743, longitude: -149.996),
        Station(icao: "KPHX", city: "Phoenix",       latitude: 33.4373, longitude: -112.008),
        Station(icao: "KLAX", city: "Los Angeles",   latitude: 33.9425, longitude: -118.408),
        Station(icao: "KDEN", city: "Denver",        latitude: 39.8561, longitude: -104.674),
        Station(icao: "KMIA", city: "Miami",         latitude: 25.7959, longitude: -80.2870),
        Station(icao: "KATL", city: "Atlanta",       latitude: 33.6407, longitude: -84.4277),
        Station(icao: "PHNL", city: "Honolulu",      latitude: 21.3187, longitude: -157.922),
        Station(icao: "KORD", city: "Chicago",       latitude: 41.9742, longitude: -87.9073),
        Station(icao: "KMSY", city: "New Orleans",   latitude: 29.9934, longitude: -90.2580),
        Station(icao: "KBOS", city: "Boston",        latitude: 42.3656, longitude: -71.0096),
        Station(icao: "KMSP", city: "Minneapolis",   latitude: 44.8820, longitude: -93.2218),
        Station(icao: "KLAS", city: "Las Vegas",     latitude: 36.0840, longitude: -115.152),
        Station(icao: "KJFK", city: "New York",      latitude: 40.6413, longitude: -73.7781),
        Station(icao: "KSEA", city: "Seattle",       latitude: 47.4502, longitude: -122.309),
        Station(icao: "KDFW", city: "Dallas",        latitude: 32.8998, longitude: -97.0403),
        Station(icao: "KIAH", city: "Houston",       latitude: 29.9844, longitude: -95.3414),
        Station(icao: "KSLC", city: "Salt Lake City", latitude: 40.7884, longitude: -111.978),
        Station(icao: "KSFO", city: "San Francisco", latitude: 37.6213, longitude: -122.379),
        Station(icao: "KPDX", city: "Portland",      latitude: 45.5887, longitude: -122.598),
        Station(icao: "KIAD", city: "Washington DC", latitude: 38.9445, longitude: -77.4558),
        Station(icao: "KDTW", city: "Detroit",       latitude: 42.2124, longitude: -83.3534),
        Station(icao: "KPHL", city: "Philadelphia",  latitude: 39.8721, longitude: -75.2411),
        Station(icao: "KCLT", city: "Charlotte",     latitude: 35.2140, longitude: -80.9431),
        Station(icao: "KBNA", city: "Nashville",     latitude: 36.1245, longitude: -86.6782),
        Station(icao: "KABQ", city: "Albuquerque",   latitude: 35.0402, longitude: -106.609),
        Station(icao: "KOKC", city: "Oklahoma City", latitude: 35.3931, longitude: -97.6007),
        Station(icao: "KBOI", city: "Boise",         latitude: 43.5644, longitude: -116.223),
        Station(icao: "KFAR", city: "Fargo",         latitude: 46.9207, longitude: -96.8158),
        Station(icao: "KMCI", city: "Kansas City",   latitude: 39.2976, longitude: -94.7139),
        Station(icao: "KBIL", city: "Billings",      latitude: 45.8077, longitude: -108.543),
    ]

    /// Stations shown on first launch before the user customises their radar.
    /// Sized to the free tier so a new user starts at, not over, the cap.
    static let defaultWatch: [String] = [
        "KPHX", "KLAX", "KORD", "KJFK", "KMIA",
    ]

    static func station(icao: String) -> Station? {
        all.first { $0.icao == icao }
    }
}
