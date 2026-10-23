import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class BackupTests: XCTestCase {
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

    private func makeEnvelope() -> BackupEnvelope {
        BackupEnvelope(
            appVersion: "1.0",
            createdAt: makeDate(2026, 10, 20),
            data: BackupData(
                incomes: [
                    IncomeBackup(IncomeEntry(amount: 1_000, date: makeDate(2026, 10, 1), type: .salary))
                ],
                expenses: [
                    ExpenseBackup(ExpenseEntry(amount: 500, date: makeDate(2026, 10, 2), category: .food))
                ],
                recurring: [
                    RecurringBackup(
                        RecurringPayment(
                            title: "Аренда",
                            category: .rent,
                            baseAmount: 47_250,
                            rounding: .up,
                            roundingStep: 100
                        )
                    )
                ],
                subscriptions: [
                    SubscriptionBackup(Subscription(name: "Музыка", amount: 199, cycle: .monthly))
                ],
                budgets: [
                    BudgetBackup(category: "food", year: 2026, month: 10, limit: 30_000, note: "")
                ],
                goals: [
                    SavingsGoalBackup(
                        name: "Отпуск", target: 150_000, saved: 45_000, deadline: nil, note: "", isActive: true)
                ],
                customCategories: [
                    CustomExpenseCategory(name: "Спорт", icon: "figure.run", tint: .orange)
                ],
                periods: [
                    PaymentPeriodBackup(
                        PaymentPeriod(
                            payment: RecurringPayment(
                                title: "Аренда",
                                category: .rent,
                                baseAmount: 47_250
                            ),
                            periodStart: makeDate(2026, 10, 1),
                            status: .paid,
                            paidDate: makeDate(2026, 10, 5)
                        )
                    )
                ],
                recurringDetails: [
                    RecurringDetailBackup(
                        recurringKey: "test",
                        endDate: makeDate(2027, 10, 1),
                        autoPay: false,
                        note: ""
                    )
                ],
                priceChanges: [
                    RecurringPriceChangeBackup(
                        recurringKey: "test",
                        effectiveDate: makeDate(2026, 10, 1),
                        amount: 50_000,
                        note: ""
                    )
                ]
            )
        )
    }

    func testEncodeDecodeRoundTrip() throws {
        let envelope = makeEnvelope()
        let data = try BackupCodec.encode(envelope)
        let decoded = try BackupCodec.decode(data)

        XCTAssertEqual(decoded.format, BackupEnvelope.formatIdentifier)
        XCTAssertEqual(decoded.formatVersion, 1)
        XCTAssertEqual(decoded.data.incomes.count, 1)
        XCTAssertEqual(decoded.data.incomes.first?.amount, 1_000)
        XCTAssertEqual(decoded.data.recurring.first?.rounding, "up")
        XCTAssertEqual(decoded.data.subscriptions.first?.name, "Музыка")
        XCTAssertEqual(decoded.data.budgets?.first?.limit, 30_000)
        XCTAssertEqual(decoded.data.goals?.first?.name, "Отпуск")
        XCTAssertEqual(decoded.data.customCategories?.first?.name, "Спорт")
        XCTAssertEqual(decoded.data.periods?.first?.status, "paid")
        XCTAssertEqual(decoded.data.recurringDetails?.first?.recurringKey, "test")
        XCTAssertEqual(decoded.data.priceChanges?.first?.amount, 50_000)
    }

    func testDecodeRejectsUnknownFormat() throws {
        var envelope = makeEnvelope()
        envelope.format = "other"
        let data = try BackupCodec.encode(envelope)
        XCTAssertThrowsError(try BackupCodec.decode(data))
    }

    func testRestoreReplace() throws {
        let context = try makeContext()
        try context.insert(IncomeEntry(amount: 99, date: makeDate(2026, 1, 1), type: .other))
        try Persistence.save(context, operation: "test.insert")

        let summary = try BackupCodec.restore(
            makeEnvelope(),
            mode: .replace,
            context: context,
            automaticBackupFolder: FileManager.default.temporaryDirectory
                .appendingPathComponent("finances-backup-tests-\(UUID().uuidString)")
        )

        XCTAssertEqual(summary.inserted, 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExpenseEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPayment>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Subscription>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Budget>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SavingsGoal>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PaymentPeriod>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringDetail>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<RecurringPriceChange>()), 1)
        XCTAssertEqual(CustomCategoryCatalog.shared.categories.count, 1)
    }

    func testRestoreMergeSkipsDuplicates() throws {
        let context = try makeContext()
        let envelope = makeEnvelope()
        let first = try BackupCodec.restore(
            envelope,
            mode: .merge,
            context: context,
            automaticBackupFolder: FileManager.default.temporaryDirectory
        )
        let second = try BackupCodec.restore(
            envelope,
            mode: .merge,
            context: context,
            automaticBackupFolder: FileManager.default.temporaryDirectory
        )

        XCTAssertEqual(first.inserted, 9)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.skipped, 9)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<IncomeEntry>()), 1)
    }

    func testAutomaticBackupWritesRotates() throws {
        let context = try makeContext()
        try context.insert(IncomeEntry(amount: 1_000, date: makeDate(2026, 10, 1), type: .salary))
        try Persistence.save(context, operation: "test.insert")

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("finances-auto-backup-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        for index in 0..<(BackupStore.maxAutomaticBackups + 2) {
            let url = try BackupStore.createAutomaticBackup(
                context: context,
                reason: "test-\(index)",
                in: folder,
                appVersion: "test"
            )
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }

        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        XCTAssertLessThanOrEqual(files.count, BackupStore.maxAutomaticBackups)
    }
}
