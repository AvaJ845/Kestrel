import Foundation

/// Honest-by-design framing, kept in one place so every surface uses the
/// same words. Kestrel is a research & education tool — never a forecast,
/// never trading or betting advice.
enum AppText {
    static let tagline = "See where the weather is breaking its own rhythm."
    static let oneLiner = "An atmospheric-anomaly radar. Research & education — not a forecast, not advice."

    static let disclaimerShort =
        "Kestrel measures how far current conditions have drifted from their recent rhythm. "
        + "It is research and education only — not a forecast, and not financial, trading, or betting advice."

    static let methodNote =
        "Each station is scored with a time-decay weighted z-score of its current temperature "
        + "against its recent hourly baseline, cross-validated against an independent sensor. "
        + "A high score means \u{201C}unusual right now,\u{201D} not \u{201C}what happens next.\u{201D}"
}

enum AppLegal {
    static let privacyURL = URL(string: "https://avaj845.github.io/Kestrel-iOS/privacy.html")!
    static let termsURL = URL(string: "https://avaj845.github.io/Kestrel-iOS/terms.html")!
    static let siteURL = URL(string: "https://avaj845.github.io/Kestrel-iOS/")!
}

/// Temperature display formatting (°C ↔ °F).
enum TempFormat {
    static func string(_ celsius: Double, fahrenheit: Bool, decimals: Int = 1) -> String {
        let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
        return String(format: "%.\(decimals)f°\(fahrenheit ? "F" : "C")", value)
    }

    /// Signed delta ("+3.2°" / "−1.1°"), unit-aware.
    static func delta(_ celsius: Double, fahrenheit: Bool, decimals: Int = 1) -> String {
        let value = fahrenheit ? celsius * 9 / 5 : celsius
        let sign = value >= 0 ? "+" : "\u{2212}"
        return String(format: "\(sign)%.\(decimals)f°", abs(value))
    }
}
