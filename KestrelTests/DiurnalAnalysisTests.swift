import XCTest
@testable import Kestrel

final class DiurnalAnalysisTests: XCTestCase {

    func testCircularHourDistance() {
        XCTAssertEqual(DiurnalAnalysis.circularHourDistance(23, 1), 2)
        XCTAssertEqual(DiurnalAnalysis.circularHourDistance(0, 12), 12)
        XCTAssertEqual(DiurnalAnalysis.circularHourDistance(5, 5), 0)
        XCTAssertEqual(DiurnalAnalysis.circularHourDistance(2, 22), 4)
    }

    func testPercentile() {
        let sample = [10.0, 12, 14, 16, 18]
        XCTAssertEqual(DiurnalAnalysis.percentile(of: 20, in: sample)!, 1.0, accuracy: 0.001)
        XCTAssertEqual(DiurnalAnalysis.percentile(of: 5, in: sample)!, 0.0, accuracy: 0.001)
        XCTAssertEqual(DiurnalAnalysis.percentile(of: 14, in: sample)!, 0.5, accuracy: 0.001) // 2 below + half of self
        XCTAssertNil(DiurnalAnalysis.percentile(of: 1, in: []))
    }

    func testSameHourBaselineFiltersToComparableHours() {
        // Build 3 days of readings at hours 0,6,12,18. "Now" is day-3 at 12:00.
        let cal = Calendar(identifier: .gregorian)
        var utc = cal; utc.timeZone = TimeZone(identifier: "UTC")!
        let now = utc.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
        var history: [Reading] = []
        for day in 1...3 {
            for hour in [0, 6, 12, 18] {
                let d = utc.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
                if d >= now { continue }
                history.append(Reading(temperatureC: Double(hour), timestamp: d))
            }
        }
        // Same-hour (±1) of 12:00 → only the hour-12 readings from days 1 & 2.
        let baseline = DiurnalAnalysis.sameHourBaseline(history: history, now: now)
        XCTAssertEqual(baseline, [12.0, 12.0])
    }
}
