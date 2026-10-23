import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class PaymentRecorderTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
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
            configurations: configuration
        )
        return ModelContext(container)
    }

    func testRecordRecurringPayment() throws {
        let context = try makeContext()
        let payment = RecurringPayment(
            title: "Аренда квартиры",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100
        )
        let date = makeDate(2026, 10, 10)

        XCTAssertTrue(try PaymentRecorder.record(payment, context: context, date: date))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        XCTAssertEqual(expenses.first?.amount, 47_300)
        XCTAssertEqual(expenses.first?.category, .rent)
        XCTAssertTrue(PaymentRecorder.isRecorded(payment, expenses: expenses, in: date))
    }

    func testRecordRecurringPaymentIsIdempotent() throws {
        let context = try makeContext()
        let payment = RecurringPayment(
            title: "Аренда квартиры",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100
        )
        let date = makeDate(2026, 10, 10)

        XCTAssertTrue(try PaymentRecorder.record(payment, context: context, date: date))
        XCTAssertFalse(try PaymentRecorder.record(payment, context: context, date: date))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)
    }

    func testVariableUtilityPaymentIsDetectedByTitle() throws {
        let context = try makeContext()
        let payment = RecurringPayment(
            title: "Коммуналка",
            category: .utilities,
            baseAmount: 6_347.32,
            rounding: .nearest,
            roundingStep: 10
        )
        let date = makeDate(2026, 10, 15)
        context.insert(
            ExpenseEntry(
                amount: 6_680,
                date: date,
                category: .utilities,
                note: "Коммуналка по счётчикам"
            ))
        try context.save()

        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        XCTAssertTrue(PaymentRecorder.isRecorded(payment, expenses: expenses, in: date))
        XCTAssertFalse(try PaymentRecorder.record(payment, context: context, date: date))
    }

    func testDifferentSubscriptionsWithSamePriceAreRecordedSeparately() throws {
        let context = try makeContext()
        let apple = Subscription(name: "Apple Music", amount: 199, cycle: .monthly)
        let spotify = Subscription(name: "Spotify", amount: 199, cycle: .monthly)
        let date = makeDate(2026, 10, 5)

        XCTAssertTrue(try PaymentRecorder.record(apple, context: context, date: date))
        XCTAssertFalse(try PaymentRecorder.record(apple, context: context, date: date))
        XCTAssertTrue(try PaymentRecorder.record(spotify, context: context, date: date))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 2)
    }

    func testInactivePaymentIsNotRecorded() throws {
        let context = try makeContext()
        let payment = RecurringPayment(
            title: "Старый платёж",
            category: .other,
            baseAmount: 1_000,
            isActive: false
        )

        XCTAssertFalse(try PaymentRecorder.record(payment, context: context, date: makeDate(2026, 10, 1)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 0)
    }
}
