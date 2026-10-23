import XCTest
@testable import FinancesCore

final class ComparisonTests: XCTestCase {
    private func expense(_ amount: Double, _ category: ExpenseCategory, _ date: Date) -> ExpenseEntry {
        ExpenseEntry(amount: amount, date: date, category: category)
    }

    func testCategoryChanges() {
        let october = makeDate(2026, 10, 1)
        let expenses = [
            expense(35_000, .food, makeDate(2026, 10, 5)),
            expense(30_000, .food, makeDate(2026, 9, 5)),
            expense(2_000, .transport, makeDate(2026, 10, 6)),
            expense(5_000, .transport, makeDate(2026, 9, 6)),
            expense(1_000, .health, makeDate(2026, 10, 7)),
        ]
        let changes = ComparisonService.categoryChanges(expenses: expenses, currentMonth: october)
        XCTAssertEqual(changes.count, 3)
        XCTAssertEqual(changes.first?.category, .food)
        XCTAssertEqual(changes.first?.delta, 5_000)
        XCTAssertEqual(changes.first?.fraction ?? -1, 5_000 / 30_000, accuracy: 0.001)
    }

    func testTotalsAndSavingsRate() {
        let month = makeDate(2026, 10, 1)
        let totals = ComparisonService.totals(
            incomes: [IncomeEntry(amount: 100_000, date: month)],
            expenses: [expense(70_000, .rent, month)],
            in: month
        )
        XCTAssertEqual(totals.net, 30_000)
        XCTAssertEqual(totals.savingsRate, 0.3, accuracy: 0.001)
    }
}
