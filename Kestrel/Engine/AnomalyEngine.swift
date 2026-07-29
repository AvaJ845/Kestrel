import Foundation

/// Kestrel's atmospheric-anomaly math, ported 1:1 from the Python
/// `guardrails.py` engine. Pure, deterministic, and unit-tested — no
/// network, no state. Every function mirrors its Python counterpart so
/// the science stays auditable.
///
/// This is a *research* engine: it measures how far current conditions
/// have drifted from their recent rhythm. It is not a forecast and not
/// advice of any kind.
enum AnomalyEngine {

    // MARK: - Z-score (time-decay weighted)

    struct ZScore: Equatable {
        let z: Double
        let weightedMean: Double
        let weightedStdDev: Double
    }

    /// Time-decay weighted z-score of `current` vs `readings`
    /// (oldest → newest). The most recent reading always has weight 1.0;
    /// older readings decay geometrically with the given half-life, so a
    /// fresh spike moves the baseline quickly and stale data barely counts.
    ///
    /// Returns `nil` when fewer than 3 readings are available.
    /// Mirrors `compute_decay_weighted_z_score`.
    static func zScore(readings: [Double],
                       current: Double,
                       halfLife: Double = EngineConfig.decayHalfLife) -> ZScore? {
        guard readings.count >= 3 else { return nil }

        let hl = halfLife > 0 ? halfLife : EngineConfig.decayHalfLife
        let n = readings.count
        let lambda = log(2.0) / hl

        // w[i] = exp(λ · (i − (n−1))) → newest (i = n−1) has weight 1.0.
        let weights = (0..<n).map { exp(lambda * Double($0 - (n - 1))) }
        let wSum = weights.reduce(0, +)

        let wMean = zip(weights, readings).reduce(0) { $0 + $1.0 * $1.1 } / wSum

        // Reliability-weighted (Bessel-analogue) variance.
        let wSqSum = weights.reduce(0) { $0 + $1 * $1 }
        let denominator = wSum - (wSqSum / wSum)
        if denominator <= 0 {
            return ZScore(z: 0, weightedMean: rounded(wMean, 2), weightedStdDev: 0)
        }

        let wVariance = zip(weights, readings)
            .reduce(0) { $0 + $1.0 * pow($1.1 - wMean, 2) } / denominator
        let wStdDev = wVariance > 0 ? sqrt(wVariance) : 0

        if wStdDev < 0.01 {
            return ZScore(z: 0, weightedMean: rounded(wMean, 2), weightedStdDev: 0)
        }

        let z = (current - wMean) / wStdDev
        return ZScore(z: rounded(z, 2),
                      weightedMean: rounded(wMean, 2),
                      weightedStdDev: rounded(wStdDev, 2))
    }

    // MARK: - Guardrail 1: validate a reading

    struct Validation: Equatable {
        let isValid: Bool
        let issues: [String]
    }

    /// Reject physically impossible readings. Mirrors `validate_reading`
    /// (bounds portion — staleness is handled at fetch time here).
    static func validate(temperatureC: Double) -> Validation {
        var issues: [String] = []
        if temperatureC < EngineConfig.tempFloorC || temperatureC > EngineConfig.tempCeilingC {
            issues.append("temp \(temperatureC)°C outside bounds "
                          + "[\(EngineConfig.tempFloorC), \(EngineConfig.tempCeilingC)]")
        }
        let outOfBounds = issues.contains { $0.contains("outside bounds") }
        return Validation(isValid: !outOfBounds, issues: issues)
    }

    // MARK: - Guardrail 2: cross-validate two independent sources

    enum CrossValidation: Equatable {
        case verified(divergenceC: Double)
        case unverified
        case divergent(divergenceC: Double)

        var label: String {
            switch self {
            case .verified: return "verified"
            case .unverified: return "unverified"
            case .divergent: return "divergent"
            }
        }
    }

    /// Compare a primary sensor temp against a second source.
    /// Mirrors `cross_validate`.
    static func crossValidate(primaryC: Double, secondaryC: Double?) -> CrossValidation {
        guard let secondaryC else { return .unverified }
        let divergence = rounded(abs(primaryC - secondaryC), 1)
        if divergence > EngineConfig.crossValidateMaxDivergenceC {
            return .divergent(divergenceC: divergence)
        }
        return .verified(divergenceC: divergence)
    }

    // MARK: - Guardrail 2b: multi-model forecast consensus

    struct Consensus: Equatable {
        enum Status: String { case consensus, uncertain, insufficient }
        let status: Status
        let meanC: Double?
        let spreadC: Double?
    }

    /// Compare daily-high forecasts across models and flag disagreement.
    /// Mirrors `compute_forecast_consensus`.
    static func consensus(models: [String: Double?]) -> Consensus {
        let available = models.compactMap { $0.value }
        guard available.count >= 2 else {
            return Consensus(status: .insufficient, meanC: nil, spreadC: nil)
        }
        let mean = rounded(available.reduce(0, +) / Double(available.count), 2)
        let spread = rounded((available.max() ?? 0) - (available.min() ?? 0), 2)
        let status: Consensus.Status =
            spread > EngineConfig.forecastConsensusDivergenceC ? .uncertain : .consensus
        return Consensus(status: status, meanC: mean, spreadC: spread)
    }

    // MARK: - Composite Confidence Engine (CCE)

    struct Confidence: Equatable {
        let composite: Int      // 0–100
        let dataQuality: Int    // 0–100
        let signalStrength: Int // 0–100
        let agreement: Int      // 0–100
    }

    /// Blend three independent dimensions into a single 0–100 confidence via
    /// a weighted geometric mean. Adapted from `composite_confidence` (CCE):
    /// the original's "market quality" dimension is replaced, in this
    /// research app, by forecast *agreement* — how much independent models
    /// concur — which is the honest analogue for a no-markets tool.
    ///
    /// - Parameters:
    ///   - zScore: anomaly z-score (nil if not enough history).
    ///   - deltaC: |current − forecast high| in °C (0 when unknown).
    ///   - crossValidation: result of `crossValidate`.
    ///   - reportAgeMinutes: age of the freshest source reading.
    ///   - consensus: multi-model forecast agreement.
    static func confidence(zScore: Double?,
                           deltaC: Double,
                           crossValidation: CrossValidation,
                           reportAgeMinutes: Int?,
                           consensus: Consensus?) -> Confidence {
        // Dimension 1: Data Quality
        var dq = 100
        switch crossValidation {
        case .divergent: dq -= 40
        case .unverified: dq -= 15
        case .verified: break
        }
        if let age = reportAgeMinutes {
            if age > 120 { dq -= 30 }
            else if age > 60 { dq -= 15 }
            else if age > 30 { dq -= 5 }
        }
        if let c = consensus, c.status == .uncertain, let spread = c.spreadC {
            dq -= min(30, Int(spread * 3.3))
        }
        dq = max(0, dq)

        // Dimension 2: Signal Strength (from anomaly magnitude + forecast gap)
        var ss = 0
        if let z = zScore {
            ss = min(60, Int(abs(z) / EngineConfig.zScoreThreshold * 40))
        }
        if deltaC < 0.5 { ss += 40 }
        else if deltaC < 2.0 { ss += 25 }
        else if deltaC < 5.0 { ss += 10 }
        ss = min(100, ss)

        // Dimension 3: Agreement (independent-model concurrence)
        var ag = 60 // neutral when we can't measure it
        if let c = consensus {
            switch c.status {
            case .consensus: ag = 100
            case .uncertain:
                let spread = c.spreadC ?? 0
                ag = max(0, 100 - Int(spread * 10))
            case .insufficient: ag = 60
            }
        }

        // Weighted geometric mean.
        let wDQ = 0.40, wSS = 0.35, wAG = 0.25
        let dqSafe = Double(max(1, dq))
        let ssSafe = Double(max(1, ss))
        let agSafe = Double(max(1, ag))
        let composite = exp(wDQ * log(dqSafe) + wSS * log(ssSafe) + wAG * log(agSafe))
        let clamped = max(0, min(100, Int(composite)))

        return Confidence(composite: clamped,
                          dataQuality: dq,
                          signalStrength: ss,
                          agreement: ag)
    }

    // MARK: - helpers

    /// Round to `places` decimals (matches Python's `round`).
    static func rounded(_ value: Double, _ places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (value * f).rounded() / f
    }
}
