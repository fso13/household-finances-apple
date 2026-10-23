import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class RecurringDetailTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: IncomeEntry.self,
            ExpenseEntry.self,
            RecurringPayment.self,
            Subscription.self,
            Budget.self,
            SavingsGoal.self,
            PaymentPeriod.self,
            RecurringDetail.self,
            RecurringPriceChange.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func payment() -> RecurringPayment {
        RecurringPayment(
            title: "Аренда",
            category: .rent,
            baseAmount: 47_250,
            startDate: makeDate(2026, 1, 10)
        )
    }

    func testEndDateDeactivatesPayment() throws {
        let payment = payment()
        let detail = RecurringDetail(payment: payment, endDate: makeDate(2026, 9, 30))
        XCTAssertTrue(
            RecurringDetailService.isActive(
                payment,
                in: makeDate(2026, 9, 1),
                details: [detail]
            )
        )
        XCTAssertFalse(
            RecurringDetailService.isActive(
                payment,
                in: makeDate(2026, 10, 1),
                details: [detail]
            )
        )
    }

    func testPriceHistoryRecordsOnlyChanges() throws {
        let context = try makeContext()
        let payment = payment()
        context.insert(payment)

        let first = RecurringDetailService.recordPriceChange(
            for: payment,
            amount: 50_000,
            date: makeDate(2026, 10, 1),
            changes: [],
            context: context
        )
        XCTAssertNotNil(first)

        let changes = try context.fetch(FetchDescriptor<RecurringPriceChange>())
        let duplicate = RecurringDetailService.recordPriceChange(
            for: payment,
            amount: 50_000,
            date: makeDate(2026, 11, 1),
            changes: changes,
            context: context
        )
        XCTAssertNil(duplicate)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPriceChange>()), 1)

        _ = RecurringDetailService.recordPriceChange(
            for: payment,
            amount: 52_000,
            date: makeDate(2026, 12, 1),
            changes: try context.fetch(FetchDescriptor<RecurringPriceChange>()),
            context: context
        )
        XCTAssertEqual(
            RecurringDetailService.history(
                for: payment,
                changes: try context.fetch(FetchDescriptor<RecurringPriceChange>())
            ).count,
            2
        )
    }
}
