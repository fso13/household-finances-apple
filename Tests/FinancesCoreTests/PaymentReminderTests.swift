import XCTest
@testable import FinancesCore

final class PaymentReminderTests: XCTestCase {
    func testUpcomingWithinHorizon() {
        let rent = RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            dayOfMonth: 25,
            startDate: makeDate(2026, 1, 25)
        )
        let later = RecurringPayment(
            title: "Гараж",
            category: .garage,
            baseAmount: 3_300,
            frequency: .quarterly,
            dayOfMonth: 5,
            startDate: makeDate(2026, 1, 5)
        )
        let reminders = PaymentReminderPlanner.upcoming(
            payments: [rent, later],
            subscriptions: [],
            now: makeDate(2026, 10, 23),
            horizonDays: 7
        )
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "Аренда")
        XCTAssertEqual(reminders.first?.date, makeDate(2026, 10, 25))
    }

    func testSubscriptionReminder() {
        let subscription = Subscription(
            name: "Музыка",
            amount: 199,
            cycle: .monthly,
            startDate: makeDate(2026, 1, 25)
        )
        let reminders = PaymentReminderPlanner.upcoming(
            payments: [],
            subscriptions: [subscription],
            now: makeDate(2026, 10, 23),
            horizonDays: 7
        )
        XCTAssertEqual(reminders.first?.title, "Музыка")
        XCTAssertEqual(reminders.first?.amount, 199)
    }
}
