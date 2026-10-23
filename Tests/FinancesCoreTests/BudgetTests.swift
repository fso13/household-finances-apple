import XCTest
@testable import FinancesCore

final class BudgetTests: XCTestCase {
    private func budget(
        _ category: ExpenseCategory,
        _ limit: Double,
        month: Date = makeDate(2026, 10, 1)
    ) -> Budget {
        Budget(
            category: category,
            year: month.year,
            month: month.month,
            limit: limit
        )
    }

    private func expense(_ amount: Double, _ category: ExpenseCategory, _ date: Date) -> ExpenseEntry {
        ExpenseEntry(amount: amount, date: date, category: category)
    }

    func testProgressAndSummary() {
        let month = makeDate(2026, 10, 1)
        let budgets = [budget(.food, 30_000), budget(.transport, 8_000)]
        let expenses = [
            expense(35_000, .food, makeDate(2026, 10, 5)),
            expense(2_000, .transport, makeDate(2026, 10, 8)),
            expense(5_000, .food, makeDate(2026, 9, 30)),
        ]

        let progress = BudgetService.progress(budgets: budgets, expenses: expenses, month: month)
        XCTAssertEqual(progress.count, 2)

        let food = progress.first { $0.category == .food }
        XCTAssertEqual(food?.limit, 30_000)
        XCTAssertEqual(food?.spent, 35_000)
        XCTAssertEqual(food?.remaining, -5_000)
        XCTAssertTrue(food?.isOver == true)

        let transport = progress.first { $0.category == .transport }
        XCTAssertEqual(transport?.spent, 2_000)
        XCTAssertFalse(transport?.isOver == true)

        let summary = BudgetService.summary(progress)
        XCTAssertEqual(summary.limit, 38_000)
        XCTAssertEqual(summary.spent, 37_000)
        XCTAssertEqual(summary.remaining, 1_000)
        XCTAssertEqual(summary.count, 2)
    }

    func testBudgetUsesKopecks() {
        let budget = budget(.food, 30_000.55)
        XCTAssertEqual(budget.limitKopecks, 3_000_055)
        XCTAssertEqual(budget.limit, 30_000.55, accuracy: 0.001)
    }

    func testBudgetLookupAndMonthMatching() {
        let october = makeDate(2026, 10, 1)
        let budgets = [budget(.food, 30_000, month: october)]
        XCTAssertNotNil(BudgetService.budget(for: .food, month: october, in: budgets))
        XCTAssertNil(
            BudgetService.budget(for: .food, month: makeDate(2026, 11, 1), in: budgets)
        )
    }

    func testEmptyBudgets() {
        let summary = BudgetService.summary([])
        XCTAssertEqual(summary.limit, 0)
        XCTAssertEqual(summary.spent, 0)
        XCTAssertEqual(summary.count, 0)
    }
}
