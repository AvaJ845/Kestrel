import Foundation

/// Tunable constants ported 1:1 from Kestrel's `config.py`.
/// Kept in one place so the science stays auditable and matches the
/// original Python engine's behaviour.
enum EngineConfig {
    /// Readings to keep for the z-score baseline.
    static let historySize = 20
    /// |z| above this is a statistically significant anomaly.
    static let zScoreThreshold = 1.5
    /// Half-life (in readings) for time-decay weighting of the baseline.
    static let decayHalfLife = 5.0

    /// Reject sensor readings outside these physical bounds (°C).
    static let tempFloorC = -60.0
    static let tempCeilingC = 60.0

    /// Flag when two sources disagree by more than this (°C).
    static let crossValidateMaxDivergenceC = 5.0
    /// Flag when two forecast models disagree by more than this (°C).
    static let forecastConsensusDivergenceC = 3.0
}
