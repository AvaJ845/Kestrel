# Kestrel (iOS)

**See where the weather is breaking its own rhythm.**

Kestrel is a native SwiftUI iPhone app that scores **atmospheric anomalies** —
how far each city's current temperature has drifted from its recent rhythm. It
is a **research and education** tool: not a forecast, and **not financial,
trading, or betting advice**.

The statistical engine is ported 1:1 from the original
[Kestrel](https://github.com/AvaJ845/Kestrel) Python project's `guardrails.py`,
and runs **entirely on-device**. No account, no tracking, no data collected.

## What it does

- **Anomaly radar** — watched stations ranked by a time-decay weighted z-score
  of current temperature vs. a recent hourly baseline.
- **Cross-validation** — each Open-Meteo reading is checked against an
  independent aviation METAR sensor; disagreement lowers confidence.
- **Composite Confidence Engine (CCE)** — blends data quality, signal strength,
  and forecast agreement into a single 0–100 score (weighted geometric mean).
- **Explainable** — every station's detail view shows the exact numbers behind
  its score.

## Architecture

| Layer | File(s) |
|---|---|
| Math engine (pure, tested) | `Kestrel/Engine/AnomalyEngine.swift`, `EngineConfig.swift` |
| Station catalog | `Kestrel/Engine/StationCatalog.swift` |
| Networking (Open-Meteo + METAR) | `Kestrel/Services/WeatherService.swift` |
| State orchestration | `Kestrel/Store/RadarStore.swift` |
| UI | `Kestrel/Views/*` |
| Honest framing / legal | `Kestrel/Support/AppLegal.swift` |
| Tests | `KestrelTests/AnomalyEngineTests.swift` |

Data sources are free and keyless: [Open-Meteo](https://open-meteo.com/) and the
[Aviation Weather Center](https://aviationweather.gov/).

## Build

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
xcodebuild -project Kestrel.xcodeproj -scheme Kestrel \
  -configuration Debug -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

The `.xcodeproj` is generated (gitignored) — `project.yml` is the source of truth.
Signing lives in `Config/Signing.xcconfig` (gitignored; copy from the `.example`).

## Honesty pledge

Kestrel produces statistical anomaly scores from public weather data. A high
score means "unusual right now," never "what happens next." It has no connection
to any market, exchange, or wager.

© AvaResearch LLC
