import XCTest
@testable import FinancesCore

final class ForecastTests: XCTestCase {
    private func expense(_ amount: Double, _ day: Int) -> ExpenseEntry {
        ExpenseEntry(amount: amount, date: makeDate(2026, 10, day), category: .food)
    }

    func testForecastForCurrentMonth() {
        let forecast = ForecastService.forecast(
            expenses: [expense(1_000, 1), expense(2_000, 5)],
            month: makeDate(2026, 10, 1),
            now: makeDate(2026, 10, 11)
        )

        XCTAssertEqual(forecast.daysElapsed, 11)
        XCTAssertEqual(forecast.daysInMonth, 31)
        XCTAssertEqual(forecast.averageDailyExpense, 3_000 / 11, accuracy: 0.01)
        XCTAssertEqual(forecast.projectedExpense, 3_000 / 11 * 31, accuracy: 0.1)
        XCTAssertFalse(forecast.isComplete)
    }

    func testForecastForPastMonth() {
        let forecast = ForecastService.forecast(
            expenses: [expense(1_000, 1), expense(2_000, 5)],
            month: makeDate(2026, 10, 1),
            now: makeDate(2026, 11, 10)
        )
        XCTAssertEqual(forecast.daysElapsed, 31)
        XCTAssertEqual(forecast.projectedExpense, 3_000)
        XCTAssertTrue(forecast.isComplete)
    }

    func testForecastForSelectedCategories() {
        let forecast = ForecastService.forecast(
            expenses: [
                expense(1_000, 1),
                ExpenseEntry(amount: 9_000, date: makeDate(2026, 10, 5), category: .rent),
            ],
            month: makeDate(2026, 10, 1),
            categories: [.food],
            now: makeDate(2026, 10, 11)
        )
        XCTAssertEqual(forecast.averageDailyExpense, 1_000 / 11, accuracy: 0.01)
        XCTAssertEqual(forecast.projectedExpense, 1_000 / 11 * 31, accuracy: 0.1)
    }

    func testForecastForFutureMonth() {
        let forecast = ForecastService.forecast(
            expenses: [],
            month: makeDate(2026, 12, 1),
            now: makeDate(2026, 10, 11)
        )
        XCTAssertEqual(forecast.daysElapsed, 0)
        XCTAssertEqual(forecast.projectedExpense, 0)
    }
}
