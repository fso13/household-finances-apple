import FinancesCore
import Foundation
import SwiftData

// MARK: - Одноразовый перенос V1 → V2

/// V1-модели лежат в отдельном модуле, чтобы прочитать старый store
/// и создать новый с деньгами в копейках. Старый файл не удаляется.
@MainActor
package enum LegacyMigration {
    @discardableResult
    package static func migrateIfNeeded(legacyURL: URL, newURL: URL) throws -> Bool {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyURL.path),
            !fileManager.fileExists(atPath: newURL.path)
        else {
            return false
        }

        let legacySchema = Schema(versionedSchema: LegacySchemaV1.self)
        let legacyConfiguration = ModelConfiguration(
            "Legacy",
            schema: legacySchema,
            url: legacyURL
        )
        let legacyContainer = try ModelContainer(
            for: legacySchema,
            configurations: legacyConfiguration
        )
        let legacyContext = ModelContext(legacyContainer)

        let incomes = try legacyContext.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))
        let expenses = try legacyContext.fetch(FetchDescriptor<ExpenseEntry>(sortBy: [SortDescriptor(\.date)]))
        let recurring = try legacyContext.fetch(FetchDescriptor<RecurringPayment>(sortBy: [SortDescriptor(\.title)]))
        let subscriptions = try legacyContext.fetch(FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)]))

        guard !(incomes.isEmpty && expenses.isEmpty && recurring.isEmpty && subscriptions.isEmpty) else {
            return false
        }

        do {
            try fileManager.createDirectory(
                at: newURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let schema = Schema(versionedSchema: FinancesSchemaV3.self)
            let configuration = ModelConfiguration(
                "FinancesV2",
                schema: schema,
                url: newURL
            )
            let container = try ModelContainer(for: schema, configurations: configuration)
            let context = ModelContext(container)

            for item in incomes {
                context.insert(
                    FinancesCore.IncomeEntry(
                        amount: item.amount,
                        date: item.date,
                        type: IncomeType(rawValue: item.typeRaw) ?? .other,
                        employer: item.employer,
                        note: item.note
                    )
                )
            }

            for item in expenses {
                context.insert(
                    FinancesCore.ExpenseEntry(
                        amount: item.amount,
                        date: item.date,
                        category: ExpenseCategory(rawValue: item.categoryRaw) ?? .other,
                        note: item.note
                    )
                )
            }

            for item in recurring {
                context.insert(
                    FinancesCore.RecurringPayment(
                        title: item.title,
                        category: ExpenseCategory(rawValue: item.categoryRaw) ?? .other,
                        baseAmount: item.baseAmount,
                        rounding: RoundingRule(rawValue: item.roundingRaw) ?? .none,
                        roundingStep: item.roundingStep,
                        frequency: PaymentFrequency(rawValue: item.frequencyRaw) ?? .monthly,
                        dayOfMonth: item.dayOfMonth,
                        startDate: item.startDate,
                        isActive: item.isActive,
                        note: item.note
                    )
                )
            }

            for item in subscriptions {
                context.insert(
                    FinancesCore.Subscription(
                        name: item.name,
                        amount: item.amount,
                        cycle: SubscriptionCycle(rawValue: item.cycleRaw) ?? .monthly,
                        startDate: item.startDate,
                        isActive: item.isActive,
                        note: item.note,
                        icon: item.icon,
                        tint: TintColor(rawValue: item.tintRaw) ?? .purple
                    )
                )
            }

            try context.save()
            AppLog.storage.info(
                "migrated V1 store: incomes \(incomes.count), expenses \(expenses.count)"
            )
            return true
        } catch {
            removeStoreFiles(at: newURL, fileManager: fileManager)
            AppLog.storage.error(
                "V1 migration failed: \(error.localizedDescription, privacy: .public)"
            )
            throw AppError.migrationFailed
        }
    }

    /// Переносит старый V1-store в Backups, чтобы сброс не запускал миграцию снова.
    @discardableResult
    package static func archiveLegacyStore(legacyURL: URL, backupFolder: URL) throws -> URL? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: legacyURL.path) else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let destination = backupFolder.appendingPathComponent(
            "Legacy-\(formatter.string(from: Date()))",
            isDirectory: true
        )
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: legacyURL.path + suffix)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = destination.appendingPathComponent("Finances.store" + suffix)
            try fileManager.copyItem(at: source, to: target)
        }

        removeStoreFiles(at: legacyURL, fileManager: fileManager)
        AppLog.storage.info("legacy store archived at \(destination.path, privacy: .public)")
        return destination
    }

    private static func removeStoreFiles(at url: URL, fileManager: FileManager) {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(fileURLWithPath: url.path + suffix)
            if fileManager.fileExists(atPath: file.path) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    #if DEBUG
    /// Создаёт старый V1-store для проверки миграции.
    package static func seedLegacyStoreForTests(at url: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        removeStoreFiles(at: url, fileManager: fileManager)

        let schema = Schema(versionedSchema: LegacySchemaV1.self)
        let configuration = ModelConfiguration("LegacyTests", schema: schema, url: url)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        context.insert(
            IncomeEntry(
                amount: 1_234.56,
                date: Date(timeIntervalSince1970: 1_790_000_000),
                typeRaw: "salary",
                employer: "Test",
                note: "legacy income"
            )
        )
        context.insert(
            ExpenseEntry(
                amount: 47_300,
                date: Date(timeIntervalSince1970: 1_790_100_000),
                categoryRaw: "rent",
                note: "legacy expense"
            )
        )
        context.insert(
            RecurringPayment(
                title: "Аренда",
                categoryRaw: "rent",
                baseAmount: 47_250,
                roundingRaw: "up",
                roundingStep: 100,
                frequencyRaw: "monthly",
                dayOfMonth: 10,
                startDate: Date(timeIntervalSince1970: 1_780_000_000),
                isActive: true,
                note: ""
            )
        )
        context.insert(
            Subscription(
                name: "Музыка",
                amount: 199,
                cycleRaw: "monthly",
                startDate: Date(timeIntervalSince1970: 1_780_000_000),
                isActive: true,
                note: "",
                icon: "music.note",
                tintRaw: "pink"
            )
        )

        try context.save()
    }
    #endif
}
