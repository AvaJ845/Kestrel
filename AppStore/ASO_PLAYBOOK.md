# Kestrel — ASO Playbook

Applying the $50K ASO Playbook's three-part engine to Kestrel. As an unknown
solo publisher, the whole game is **rank for terms people actually type**, then
**convert the tap**, then **compound with reviews**.

## 1 · Discovery — get found  ✅ (built, in `METADATA.md`)
Apple indexes **App Name + Subtitle + Keywords** as one string, so every word
is spent once, keyword-first, no repeats.
- **App Store Name (≤30):** `Weather Anomaly - Kestrel` — primary keyword FIRST, brand second. Home-screen name stays `Kestrel`.
- **Subtitle (≤30):** `Track unusual heat & cold` — all-new words.
- **Keywords (≤100):** `climate,meteorology,science,degree,celsius,fahrenheit,metar,station,radar,heatwave,coldsnap,data` — comma-joined, no spaces, singulars, no competitor names.
- **Combinations harvested:** `weather anomaly`, `weather station`, `weather radar`, `climate data`, `temperature anomaly`, `weather science`.
- **Deliberately excluded:** `forecast`, `prediction`, `bet`, `market`, `trade` — they'd contradict the app's own "not a forecast, not advice" framing and invite App-Review questions.

## 2 · Conversion — win the tap  ⏳ (icon ✅, screenshots pending)
- [x] **App icon** — the mark *is* the product (baseline + anomaly spike on a warm dusk gradient). `Tools/make_icon.py` → `AppStore/AppIcon-1024.png` + 3 in-app variants.
- [ ] **Screenshots (6.9")** — lead with the payoff, one idea per frame, big legible captions. Order in `METADATA.md`: radar hero → explainable detail (rhythm chart) → spike alerts → app icons → honesty pledge.
- [ ] **(Optional) App Preview** — a 15–20s loop of one radar refresh + tapping into a station's rhythm chart.
- **Product-page A/B test (after launch):** first test = radar-hero screenshot vs. the rhythm-chart detail as frame #1.

## 3 · Momentum — compound  ⏳ (post-launch)
- [x] **Ask at a happy moment**, never at launch — `ReviewPrompt` fires `requestReview` after the 3rd successful radar refresh, once per app version (wired in `RadarView`).
- [ ] **Reply to every review** — thank the good, fix the bad (1★→5★).
- [ ] **Roadmap signal:** if ~20 reviews ask the same thing (e.g. more cities, a widget), build it and reply that you shipped it.
- [ ] Track keyword rank monthly; rotate the weakest hidden keyword each update.

## Status
- Discovery: **done** (paste-ready in `METADATA.md`).
- Conversion: icon **done**; screenshots + optional preview **pending** (need the app running on a 6.9" sim).
- Momentum: review-prompt gate **wired**; replying to reviews + keyword tracking are **post-launch** operations.
