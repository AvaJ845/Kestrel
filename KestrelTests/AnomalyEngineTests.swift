import XCTest
@testable import Kestrel

/// Locks the Swift port to the behaviour of Kestrel's Python `guardrails.py`.
final class AnomalyEngineTests: XCTestCase {

    // MARK: Z-score

    func testZScoreNeedsAtLeastThreeReadings() {
        XCTAssertNil(AnomalyEngine.zScore(readings: [10, 12], current: 20))
        XCTAssertNotNil(AnomalyEngine.zScore(readings: [10, 12, 14], current: 20))
    }

    func testZScoreConstantSeriesIsZero() {
        let result = AnomalyEngine.zScore(readings: [15, 15, 15, 15], current: 20)
        XCTAssertEqual(result?.z, 0)
        XCTAssertEqual(result?.weightedStdDev, 0)
    }

    /// Golden values computed from the Python decay-weighted formula
    /// (half-life 5): z ≈ 1.02, weighted mean ≈ 14.47, weighted σ ≈ 5.41.
    func testZScoreDecayWeightedGoldenValue() {
        let result = AnomalyEngine.zScore(readings: [10, 12, 20], current: 20)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.z, 1.02, accuracy: 0.02)
        XCTAssertEqual(result!.weightedMean, 14.47, accuracy: 0.05)
        XCTAssertEqual(result!.weightedStdDev, 5.41, accuracy: 0.05)
    }

    func testZScoreSignFollowsDirection() {
        let warm = AnomalyEngine.zScore(readings: [10, 11, 12, 13], current: 20)
        let cold = AnomalyEngine.zScore(readings: [10, 11, 12, 13], current: 2)
        XCTAssertGreaterThan(warm!.z, 0)
        XCTAssertLessThan(cold!.z, 0)
    }

    func testRecencyWeightingMattersVsUniform() {
        // Departing from a CALM recent baseline reads as more anomalous than
        // the same value when the spike already sits in the recent (heavily
        // weighted) window — because a recent spike pulls the baseline toward
        // itself, shrinking the z. This is the whole point of decay weighting.
        let calmRecentBaseline = AnomalyEngine.zScore(readings: [25, 10, 10, 10], current: 25)
        let spikeInRecentWindow = AnomalyEngine.zScore(readings: [10, 10, 10, 25], current: 25)
        XCTAssertGreaterThan(abs(calmRecentBaseline!.z), abs(spikeInRecentWindow!.z))
    }

    // MARK: Validate

    func testValidateBounds() {
        XCTAssertTrue(AnomalyEngine.validate(temperatureC: 22).isValid)
        XCTAssertFalse(AnomalyEngine.validate(temperatureC: 99).isValid)
        XCTAssertFalse(AnomalyEngine.validate(temperatureC: -80).isValid)
    }

    // MARK: Cross-validate

    func testCrossValidateStatuses() {
        XCTAssertEqual(AnomalyEngine.crossValidate(primaryC: 20, secondaryC: nil), .unverified)
        XCTAssertEqual(AnomalyEngine.crossValidate(primaryC: 20, secondaryC: 22),
                       .verified(divergenceC: 2.0))
        XCTAssertEqual(AnomalyEngine.crossValidate(primaryC: 20, secondaryC: 30),
                       .divergent(divergenceC: 10.0))
    }

    // MARK: Consensus

    func testConsensus() {
        XCTAssertEqual(AnomalyEngine.consensus(models: ["a": 20]).status, .insufficient)
        XCTAssertEqual(AnomalyEngine.consensus(models: ["a": 20, "b": 21]).status, .consensus)
        XCTAssertEqual(AnomalyEngine.consensus(models: ["a": 20, "b": 26]).status, .uncertain)
    }

    // MARK: Confidence (CCE)

    func testConfidenceIsBounded() {
        let c = AnomalyEngine.confidence(
            zScore: 3.0, deltaC: 0.2,
            crossValidation: .verified(divergenceC: 0.5),
            reportAgeMinutes: 5, consensus: nil)
        XCTAssertTrue((0...100).contains(c.composite))
        XCTAssertTrue((0...100).contains(c.dataQuality))
    }

    func testConfidenceRewardsCleanFreshVerifiedData() {
        let clean = AnomalyEngine.confidence(
            zScore: 3.0, deltaC: 0.2,
            crossValidation: .verified(divergenceC: 0.5),
            reportAgeMinutes: 5, consensus: nil)
        let messy = AnomalyEngine.confidence(
            zScore: 3.0, deltaC: 0.2,
            crossValidation: .divergent(divergenceC: 9),
            reportAgeMinutes: 200, consensus: nil)
        XCTAssertGreaterThan(clean.composite, messy.composite)
    }

    // MARK: Tier classification

    func testTierThresholds() {
        XCTAssertEqual(Anomaly.Tier(z: 0.5), .normal)
        XCTAssertEqual(Anomaly.Tier(z: 1.6), .notable)
        XCTAssertEqual(Anomaly.Tier(z: 2.4), .high)
        XCTAssertEqual(Anomaly.Tier(z: 3.5), .extreme)
        XCTAssertEqual(Anomaly.Tier(z: nil), .normal)
    }
}
