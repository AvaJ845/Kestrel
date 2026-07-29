import SwiftUI
import Charts

/// Explains one station's reading in plain English, shows the recent rhythm as
/// a chart with a shaded normal band, and lists the numbers behind the score.
/// Explainability is a first-class feature — no black boxes.
struct AnomalyDetailView: View {
    let anomaly: Anomaly
    let fahrenheit: Bool
    let isPro: Bool
    var store: RadarStore?
    @State private var consensus: AnomalyEngine.Consensus?
    @State private var loadingConsensus = false

    var body: some View {
        List {
            headerSection
            if anomaly.sparkline.count > 1 { chartSection }
            numbersSection
            if isPro { consensusSection }
            methodSection
            if !isPro { proNudgeSection }
            disclaimerSection
        }
        .navigationTitle(anomaly.station.city)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard isPro, let store, consensus == nil else { return }
            loadingConsensus = true
            consensus = await store.loadConsensus(for: anomaly.station)
            loadingConsensus = false
        }
    }

    private var consensusSection: some View {
        Section("Model agreement (Pro)") {
            if let c = consensus, c.status != .insufficient {
                HStack {
                    Text(consensusHeadline(c))
                    Spacer()
                    if let spread = c.spreadC {
                        Text(TempFormat.delta(spread, fahrenheit: fahrenheit)).monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Text("How much independent weather models agree on today's high — a confidence signal, not a Kestrel forecast.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if loadingConsensus {
                HStack { ProgressView(); Text("Checking models…").foregroundStyle(.secondary) }
            } else {
                Text("Model agreement isn't available for this station right now.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func consensusHeadline(_ c: AnomalyEngine.Consensus) -> String {
        switch c.status {
        case .consensus: return "Models agree"
        case .uncertain: return "Models disagree — treat as uncertain"
        case .insufficient: return "Not enough models"
        }
    }

    // MARK: sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: anomaly.tier.symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(anomaly.tier.color)
                Text(anomaly.tier.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(anomaly.tier.color)
                Text(AnomalyPhrasing.interpretation(for: anomaly, fahrenheit: fahrenheit))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                Text(AnomalyPhrasing.meaning(for: anomaly))
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var chartSection: some View {
        Section("Recent rhythm") {
            Chart {
                if let lo = anomaly.bandLowC, let hi = anomaly.bandHighC {
                    RectangleMark(
                        xStart: .value("Start", 0),
                        xEnd: .value("End", anomaly.sparkline.count - 1),
                        yStart: .value("Low", conv(lo)),
                        yEnd: .value("High", conv(hi))
                    )
                    .foregroundStyle(anomaly.tier.color.opacity(0.12))
                }
                ForEach(Array(anomaly.sparkline.enumerated()), id: \.offset) { idx, temp in
                    LineMark(x: .value("Hour", idx), y: .value("Temp", conv(temp)))
                        .foregroundStyle(.secondary)
                        .interpolationMethod(.catmullRom)
                }
                PointMark(
                    x: .value("Hour", anomaly.sparkline.count - 1),
                    y: .value("Temp", conv(anomaly.currentTempC))
                )
                .foregroundStyle(anomaly.tier.color)
                .symbolSize(120)
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(Int(v))°")
                        }
                    }
                }
            }
            .accessibilityLabel("Recent temperature rhythm for \(anomaly.station.city). "
                + "The shaded band is its normal range; the marked point is now.")
            Text(AnomalyPhrasing.baselineNote(for: anomaly))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var numbersSection: some View {
        Section("The numbers") {
            metric("Current temperature", TempFormat.string(anomaly.currentTempC, fahrenheit: fahrenheit))
            metric("Usual for this hour", TempFormat.string(anomaly.baselineMeanC, fahrenheit: fahrenheit))
            metric("Drift from rhythm", TempFormat.delta(anomaly.deltaC, fahrenheit: fahrenheit))
            if let z = anomaly.z {
                metric("Anomaly (z-score)", String(format: "%.2f\u{03C3}", z))
            }
            if let p = anomaly.percentile {
                metric("Percentile vs comparable hours", "\(Int((p * 100).rounded()))%")
            }
            if let high = anomaly.forecastHighC {
                metric("Today's forecast high", TempFormat.string(high, fahrenheit: fahrenheit))
            }
            metric("Cross-validation", anomaly.crossValidation.capitalized)
            metric("Confidence", "\(anomaly.confidence) / 100")
        }
    }

    private var methodSection: some View {
        Section("How to read this") {
            Text(AppText.methodNote).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var proNudgeSection: some View {
        Section {
            Label("Kestrel Pro scores against a 30-day same-hour baseline and adds multi-model agreement — steadier, less noisy anomalies.",
                  systemImage: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var disclaimerSection: some View {
        Section {
            Text(AppText.disclaimerShort).font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: helpers

    private func conv(_ celsius: Double) -> Double {
        fahrenheit ? celsius * 9 / 5 + 32 : celsius
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}
