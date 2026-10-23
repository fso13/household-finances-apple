import FinancesLegacy
import SwiftData
import XCTest
@testable import FinancesCore

@MainActor
final class MigrationTests: XCTestCase {
    func testMigrationFromV1Store() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("finances-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let legacyURL = folder.appendingPathComponent("Finances.store")
        let newURL = folder.appendingPathComponent("FinancesV2.store")

        try LegacyMigration.seedLegacyStoreForTests(at: legacyURL)
        XCTAssertTrue(try LegacyMigration.migrateIfNeeded(legacyURL: legacyURL, newURL: newURL))

        let schema = Schema(versionedSchema: FinancesSchemaV5.self)
        let configuration = ModelConfiguration("FinancesV2", schema: schema, url: newURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let incomes = try context.fetch(FetchDescriptor<IncomeEntry>())
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let recurring = try context.fetch(FetchDescriptor<RecurringPayment>())
        let subscriptions = try context.fetch(FetchDescriptor<Subscription>())

        XCTAssertEqual(incomes.count, 1)
        XCTAssertEqual(incomes.first?.amountKopecks, 123_456)
        XCTAssertEqual(incomes.first?.amount, 1_234.56)
        XCTAssertEqual(expenses.first?.amountKopecks, 4_730_000)
        XCTAssertEqual(recurring.first?.baseAmountKopecks, 4_725_000)
        XCTAssertEqual(recurring.first?.roundingStepKopecks, 10_000)
        XCTAssertEqual(subscriptions.first?.amountKopecks, 19_900)

        XCTAssertFalse(try LegacyMigration.migrateIfNeeded(legacyURL: legacyURL, newURL: newURL))
    }

    func testArchiveLegacyStore() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("finances-archive-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let legacyURL = folder.appendingPathComponent("Finances.store")
        try LegacyMigration.seedLegacyStoreForTests(at: legacyURL)

        let archives = folder.appendingPathComponent("Backups", isDirectory: true)
        let archived = try LegacyMigration.archiveLegacyStore(
            legacyURL: legacyURL,
            backupFolder: archives
        )

        XCTAssertNotNil(archived)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: archived!.path))
    }
}
