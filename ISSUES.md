# Kestrel — QA / Value Tracker

Status of the complete-build pass. P0 = ship blocker, P1 = value/experience, P2 = polish.

## P0 — blockers
- [x] **Legal pages 404** — Privacy/Terms links dead. → GitHub Pages was never enabled; enabled `main`/`/docs` via API (HTTP 201). Verify 200.
- [x] **"30-day baseline" is invisible** — Pro advertises a 30-day baseline but the UI exposes no control, so it reads as a phantom feature. → Added a real **Baseline window** picker (7 / 14 / 30 days) in Settings; free locked at 7 with a Pro nudge; hero + refresh use the chosen window.

## P1 — value & experience (data-scientist + Fellow lens)
- [x] **Lead with meaning, not jargon** — a bare "−2.4σ" doesn't tell a user anything. → Detail now leads with a plain "what this means / how notable" read; row shows a short plain qualifier; σ stays as the compact instrument badge.
- [x] **"So what?" context** — every reading now answers: how far from normal (real degrees), how unusual (percentile), and whether it's worth a glance.

## P2 — polish
- [x] **Row text truncation** ("unusually war…") — shortened the row qualifier so it never clips.
- [x] Empty/again states, °C/°F consistency, alerts-permission-denied path — audited.

## QA sweep (edge cases checked)
- [x] < 3 comparable readings → shows "—" + "not enough comparable history"; no crash.
- [x] All fetches fail → error banner, pull-to-retry.
- [x] Single station / empty radar → empty state with CTA.
- [x] Notifications denied → Settings shows the state; no repeated prompts.
- [x] Extreme/out-of-bounds temps → rejected by `validate`.
