import XCTest
@testable import FinancesCore

@MainActor
final class PaymentCalendarTests: XCTestCase {
    func testCalendarMixesRecurringAndSubscriptions() {
        let rent = RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            dayOfMonth: 10,
            startDate: makeDate(2026, 1, 10)
        )
        let internet = Subscription(
            name: "Интернет",
            amount: 1_450,
            cycle: .monthly,
            startDate: makeDate(2026, 1, 5)
        )

        let items = PaymentCalendarService.upcoming(
            payments: [rent],
            subscriptions: [internet],
            periods: [],
            expenses: [],
            month: makeDate(2026, 10, 1),
            now: makeDate(2026, 10, 1)
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.title, "Интернет")
        XCTAssertEqual(items.last?.title, "Аренда")
        XCTAssertFalse(items.first?.isOverdue == true)
    }

    func testCalendarMarksPaidAndOverdue() {
        let rent = RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            dayOfMonth: 10,
            startDate: makeDate(2026, 1, 10)
        )
        let expense = ExpenseEntry(
            amount: 47_250,
            date: makeDate(2026, 10, 10),
            category: .rent,
            note: "Аренда"
        )
        let items = PaymentCalendarService.upcoming(
            payments: [rent],
            subscriptions: [],
            periods: [],
            expenses: [expense],
            month: makeDate(2026, 10, 1),
            now: makeDate(2026, 10, 15)
        )
        XCTAssertEqual(items.first?.status, .paid)
        XCTAssertFalse(items.first?.isOverdue == true)
    }
}
