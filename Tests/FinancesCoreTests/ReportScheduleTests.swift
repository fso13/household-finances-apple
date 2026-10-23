import XCTest
@testable import FinancesCore

final class ReportScheduleTests: XCTestCase {
    func testNeverGeneratedIsDue() {
        XCTAssertTrue(
            ReportSchedulePlanner.isDue(
                lastGenerated: nil,
                frequency: .weekly,
                now: makeDate(2026, 10, 23)
            )
        )
    }

    func testWeeklyAndMonthly() {
        let last = makeDate(2026, 10, 1)
        XCTAssertFalse(
            ReportSchedulePlanner.isDue(
                lastGenerated: last,
                frequency: .weekly,
                now: makeDate(2026, 10, 5)
            )
        )
        XCTAssertTrue(
            ReportSchedulePlanner.isDue(
                lastGenerated: last,
                frequency: .weekly,
                now: makeDate(2026, 10, 9)
            )
        )
        XCTAssertFalse(
            ReportSchedulePlanner.isDue(
                lastGenerated: last,
                frequency: .monthly,
                now: makeDate(2026, 10, 25)
            )
        )
        XCTAssertTrue(
            ReportSchedulePlanner.isDue(
                lastGenerated: last,
                frequency: .monthly,
                now: makeDate(2026, 11, 1)
            )
        )
    }
}
