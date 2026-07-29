import SwiftUI

/// Explains one station's reading in plain English, with the numbers that
/// produced it. Explainability is a first-class feature — no black boxes.
struct AnomalyDetailView: View {
    let anomaly: Anomaly
    let fahrenheit: Bool

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: anomaly.tier.symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(anomaly.tier.color)
                    Text(anomaly.tier.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(anomaly.tier.color)
                    Text(headline)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("The numbers") {
                metric("Current temperature",
                       TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit))
                metric("Recent baseline (weighted)",
                       TempFormat.string(anomaly.baselineMeanC, fahrenheit: fahrenheit))
                metric("Drift from rhythm",
                       "\(TempFormat.delta(anomaly.deltaC, fahrenheit: fahrenheit))")
                if let z = anomaly.z {
                    metric("Anomaly (z-score)", String(format: "%.2f\u{03C3}", z))
                }
                if let high = anomaly.forecastHighC {
                    metric("Today's forecast high",
                           TempFormat.string(high, fahrenheit: fahrenheit))
                }
                metric("Cross-validation", anomaly.crossValidation.capitalized)
                metric("Confidence", "\(anomaly.confidence) / 100")
            }

            Section("How to read this") {
                Text(AppText.methodNote)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text(AppText.disclaimerShort)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(anomaly.station.city)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headline: String {
        guard anomaly.z != nil else {
            return "Not enough recent history yet to score an anomaly here."
        }
        let dir = anomaly.deltaC >= 0 ? "warmer" : "cooler"
        let mag = TempFormat.delta(anomaly.deltaC, fahrenheit: fahrenheit)
        switch anomaly.tier {
        case .normal:
            return "\(anomaly.station.city) is tracking close to its recent rhythm."
        default:
            return "\(anomaly.station.city) is running \(mag) \(dir) than its recent rhythm right now."
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
