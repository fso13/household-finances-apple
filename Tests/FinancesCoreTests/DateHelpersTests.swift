import XCTest
@testable import FinancesCore

final class DateHelpersTests: XCTestCase {
    func testStartOfMonth() {
        let date = makeDate(2026, 1, 31)
        XCTAssertEqual(date.startOfMonth.components, makeDate(2026, 1, 1).components)
    }

    func testStartOfYear() {
        let date = makeDate(2026, 7, 14)
        XCTAssertEqual(date.startOfYear.components, makeDate(2026, 1, 1).components)
    }

    func testQuarters() {
        XCTAssertEqual(makeDate(2026, 1, 1).quarter, 1)
        XCTAssertEqual(makeDate(2026, 3, 31).quarter, 1)
        XCTAssertEqual(makeDate(2026, 4, 1).quarter, 2)
        XCTAssertEqual(makeDate(2026, 9, 30).quarter, 3)
        XCTAssertEqual(makeDate(2026, 10, 1).quarter, 4)
        XCTAssertEqual(makeDate(2026, 12, 31).quarter, 4)
    }

    func testAddingMonthsAcrossYearBoundary() {
        let december = makeDate(2026, 12, 15)
        XCTAssertEqual(december.addingMonths(1).components, makeDate(2027, 1, 15).components)
        XCTAssertEqual(december.addingMonths(-11).components, makeDate(2026, 1, 15).components)
    }

    func testSameMonthAndYear() {
        XCTAssertTrue(makeDate(2026, 10, 1).isSameMonth(as: makeDate(2026, 10, 31)))
        XCTAssertFalse(makeDate(2026, 10, 1).isSameMonth(as: makeDate(2026, 11, 1)))
        XCTAssertTrue(makeDate(2026, 1, 1).isSameYear(as: makeDate(2026, 12, 31)))
    }

    func testNextOccurrenceUsesReferenceDate() {
        let start = makeDate(2026, 1, 10)
        let next = start.nextOccurrence(
            everyMonths: 1,
            from: start,
            relativeTo: makeDate(2026, 3, 15)
        )
        XCTAssertEqual(next.components, makeDate(2026, 4, 10).components)
    }

    func testNextOccurrenceQuarterly() {
        let start = makeDate(2026, 1, 5)
        let next = start.nextOccurrence(
            everyMonths: 3,
            from: start,
            relativeTo: makeDate(2026, 2, 1)
        )
        XCTAssertEqual(next.components, makeDate(2026, 4, 5).components)
    }

    func testNextOccurrenceReturnsStartWhenItIsInFuture() {
        let start = makeDate(2026, 12, 1)
        let next = start.nextOccurrence(
            everyMonths: 1,
            from: start,
            relativeTo: makeDate(2026, 1, 1)
        )
        XCTAssertEqual(next.components, start.components)
    }
}
