import SwiftUI

/// One station in the radar list: city, current temp, drift from its recent
/// rhythm, a tier badge, and a confidence chip.
struct AnomalyRow: View {
    let anomaly: Anomaly
    let fahrenheit: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(anomaly.tier.color.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: anomaly.tier.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(anomaly.tier.color)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(anomaly.station.city)
                    .font(.body.weight(.semibold))
                HStack(spacing: 6) {
                    Text(TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit))
                        .monospacedDigit()
                    Text("·")
                    Text("\(TempFormat.delta(anomaly.deltaC, fahrenheit: fahrenheit)) vs rhythm")
                        .monospacedDigit()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                if let z = anomaly.z {
                    Text("\(z >= 0 ? "+" : "\u{2212}")\(String(format: "%.1f", abs(z)))\u{03C3}")
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(anomaly.tier.color)
                } else {
                    Text("—")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                ConfidenceChip(value: anomaly.confidence)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let temp = TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit, decimals: 0)
        let zText = anomaly.z.map { String(format: "%.1f sigma", $0) } ?? "not enough history"
        return "\(anomaly.station.city), \(temp), \(anomaly.tier.title), "
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
            Image(systemName: "gauge.medium")
                .font(.caption2)
            Text("\(value)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}
