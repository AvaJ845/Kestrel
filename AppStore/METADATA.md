# App Store — Kestrel

## Identity — Discovery (keyword-first, per the ASO playbook)
- **App Store Name (≤30):** `Weather Anomaly - Kestrel`  *(25 chars — primary keyword FIRST, brand second)*
  - Home Screen name stays `Kestrel` (CFBundleDisplayName). Same pattern as "Habit Tracker - Habit Kit" showing as "Habit Kit" on device.
- **Subtitle (≤30):** `Track unusual heat & cold`  *(25 chars — all new words, none repeated from the Name)*
  - Alts: `Live temperature anomalies` *(26)* · `Spot weather out of rhythm` *(26)*
- **Bundle ID:** com.avaresearch.kestrel
- **Primary category:** Weather  ·  **Secondary:** Education
- **Age rating:** 4+ (no objectionable content)
- **Price:** Free. (No account, no IAP in v1. Optional Pro convenience tier is a
  possible later addition — not needed to ship.)

## Promotional text (≤170)
See where the weather is breaking its own rhythm. Kestrel scores how unusual each city is right now — on-device, private. Research & education, never advice.

## Keywords (≤100) — the hidden backend array
`climate,meteorology,science,degree,celsius,fahrenheit,metar,station,radar,heatwave,coldsnap,data`  *(96 chars)*

Rules applied (per the playbook): comma-separated, **no spaces**, **no word repeated** from the Name or Subtitle, **singulars**, **no competitor names**. Apple indexes Name + Subtitle + Keywords as one string, so these combine into phrases like `weather science`, `climate data`, `temperature anomaly`, `weather station`, `weather radar`.

> **Decision on `forecast`:** deliberately **excluded**. Kestrel states on every surface that it is *not a forecast*; using `forecast` as a keyword would contradict the app's own framing and invite App-Review questions. `prediction`, `bet`, `market`, and `trade` are excluded for the same reason — Kestrel is a research tool with no market surface.

## Description
Kestrel is an atmospheric-anomaly radar. It measures how far each city's current temperature has drifted from its **recent rhythm** — a statistical "z-score" built entirely from public weather data, right on your device. It is a learning tool, not a crystal ball: it tells you what's *unusual right now*, never what happens next.

**Honest by design**
• Each station is scored with a time-decay weighted z-score against its recent hourly baseline — recent hours count most.
• Every reading is cross-validated against an independent aviation sensor (METAR); disagreement lowers the confidence score.
• Tap any city to see the exact numbers: baseline, drift, z-score, and confidence. No black boxes.

**Yours, and private**
• Everything runs on your device. No account. No tracking. No data collected.
• Choose the cities you want to watch; Kestrel only fetches weather for those.

Kestrel is for learning and exploration only and is **not a forecast** and **not financial, investment, trading, or betting advice.** It has no connection to any market, exchange, or wager.

## What's New (1.0)
First release: an on-device atmospheric-anomaly radar. Rank cities by how far they've drifted from their recent rhythm, cross-validated against an independent sensor, with the full math shown for every station — research & education, never advice.

## URLs
- **Support / Marketing:** https://avaj845.github.io/Kestrel-iOS/
- **Privacy Policy:** https://avaj845.github.io/Kestrel-iOS/privacy.html
- **Terms of Use (EULA):** https://avaj845.github.io/Kestrel-iOS/terms.html (or Apple standard EULA)

## App Privacy (nutrition label)
- **Data collected:** None. No account, no analytics/tracking SDKs.
- Network requests fetch only public weather data (Open-Meteo, aviation METAR) for the stations the user chooses.

## Review notes (paste into App Review)
Kestrel is a **research and education** tool. It computes a statistical anomaly score (a z-score of current temperature vs. a recent baseline) for public weather stations and clearly labels itself as **not a forecast** and **not financial, trading, or betting advice** throughout (radar footer, station detail, About). It contains no market data, no wagering, no brokerage, no accounts, and no real-money activity of any kind. All weather data is public and fetched on-device.
