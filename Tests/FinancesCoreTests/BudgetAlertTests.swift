import XCTest
@testable import FinancesCore

final class BudgetAlertTests: XCTestCase {
    func testOnlyOverBudgetAlerts() {
        let month = makeDate(2026, 10, 1)
        let over = BudgetProgress(
            id: "food",
            category: .food,
            limit: 30_000,
            spent: 35_000,
            note: ""
        )
        let under = BudgetProgress(
            id: "transport",
            category: .transport,
            limit: 8_000,
            spent: 2_000,
            note: ""
        )

        let alerts = BudgetAlertService.alerts(for: [over, under], month: month)
        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.id, "budget-2026-10-food")
        XCTAssertTrue(alerts.first?.title.contains("Продукты") == true)
    }
}
