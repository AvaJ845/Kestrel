import SwiftUI

/// One station in the radar list: tier glyph, city + calibrated qualifier, a
/// rhythm sparkline, and the anomaly magnitude with a confidence chip.
struct AnomalyRow: View {
    let anomaly: Anomaly
    let fahrenheit: Bool
    var alertEnabled: Bool = false

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle().fill(anomaly.tier.color.opacity(0.16)).frame(width: 42, height: 42)
                Image(systemName: anomaly.tier.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(anomaly.tier.color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(anomaly.station.city).font(.body.weight(.semibold))
                    if alertEnabled {
                        Image(systemName: "bell.fill")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Spike alert on")
                    }
                }
                Text(TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit)
                     + " · " + AnomalyPhrasing.rowQualifier(for: anomaly))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Sparkline(values: anomaly.sparkline,
                      bandLow: anomaly.bandLowC, bandHigh: anomaly.bandHighC,
                      tint: anomaly.tier == .normal ? .secondary : anomaly.tier.color)
                .frame(width: 56, height: 30)

            VStack(alignment: .trailing, spacing: 3) {
                if let z = anomaly.z {
                    Text("\(z >= 0 ? "+" : "\u{2212}")\(String(format: "%.1f", abs(z)))\u{03C3}")
                        .font(.subheadline.weight(.bold)).monospacedDigit()
                        .foregroundStyle(anomaly.tier.color)
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.secondary)
                }
                ConfidenceChip(value: anomaly.confidence)
            }
            .frame(minWidth: 44, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let temp = TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit, decimals: 0)
        let zText = anomaly.z.map { String(format: "%.1f sigma", $0) } ?? "not enough history"
        return "\(anomaly.station.city), \(temp), \(AnomalyPhrasing.rowQualifier(for: anomaly)), "
            + "\(zText), confidence \(anomaly.confidence) percent"
    }
}

struct ConfidenceChip: View {
    let value: Int
    private var color: Color {
        switch value {
        case 70...: return .green
        case 45..<70: return .yellow
        default: return .secondary
        }
    }
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "gauge.medium").font(.caption2)
            Text("\(value)").font(.caption.weight(.semibold)).monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}
