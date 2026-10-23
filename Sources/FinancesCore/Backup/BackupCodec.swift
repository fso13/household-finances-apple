import Foundation
import SwiftData

// MARK: - Кодек бэкапа

package enum BackupCodec {
    package static func encode(_ envelope: BackupEnvelope) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        do {
            return try encoder.encode(envelope)
        } catch {
            AppLog.export.error("backup encode failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }
    }

    package static func decode(_ data: Data) throws -> BackupEnvelope {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let envelope: BackupEnvelope
        do {
            envelope = try decoder.decode(BackupEnvelope.self, from: data)
        } catch {
            AppLog.import.error("backup decode failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.importFailed
        }

        guard envelope.format == BackupEnvelope.formatIdentifier,
            envelope.formatVersion <= BackupEnvelope.currentFormatVersion
        else {
            throw AppError.importFailed
        }

        return envelope
    }

    package static func makeEnvelope(
        context: ModelContext,
        appVersion: String,
        createdAt: Date = Date()
    ) throws -> BackupEnvelope {
        do {
            let incomes = try context.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))
            let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>(sortBy: [SortDescriptor(\.date)]))
            let recurring = try context.fetch(FetchDescriptor<RecurringPayment>(sortBy: [SortDescriptor(\.title)]))
            let subscriptions = try context.fetch(FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)]))
            let budgets = try context.fetch(
                FetchDescriptor<Budget>(sortBy: [SortDescriptor(\.year), SortDescriptor(\.month)])
            )
            let goals = try context.fetch(FetchDescriptor<SavingsGoal>(sortBy: [SortDescriptor(\.name)]))
            let customCategories = CustomCategoryCatalog.shared.categories
            let periods = try context.fetch(
                FetchDescriptor<PaymentPeriod>(sortBy: [SortDescriptor(\.periodStart), SortDescriptor(\.title)])
            )
            let details = try context.fetch(FetchDescriptor<RecurringDetail>())
            let priceChanges = try context.fetch(
                FetchDescriptor<RecurringPriceChange>(sortBy: [SortDescriptor(\.effectiveDate)])
            )

            return BackupEnvelope(
                appVersion: appVersion,
                createdAt: createdAt,
                data: BackupData(
                    incomes: incomes.map(IncomeBackup.init),
                    expenses: expenses.map(ExpenseBackup.init),
                    recurring: recurring.map(RecurringBackup.init),
                    subscriptions: subscriptions.map(SubscriptionBackup.init),
                    budgets: budgets.map(BudgetBackup.init),
                    goals: goals.map(SavingsGoalBackup.init),
                    customCategories: customCategories,
                    periods: periods.map(PaymentPeriodBackup.init),
                    recurringDetails: details.map(RecurringDetailBackup.init),
                    priceChanges: priceChanges.map(RecurringPriceChangeBackup.init)
                )
            )
        } catch {
            AppLog.export.error("backup fetch failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }
    }

    @MainActor
    package static func restore(
        _ envelope: BackupEnvelope,
        mode: RestoreMode,
        context: ModelContext,
        automaticBackupFolder: URL = StoreLocation.backupsFolder
    ) throws -> RestoreSummary {
        guard envelope.format == BackupEnvelope.formatIdentifier,
            envelope.formatVersion <= BackupEnvelope.currentFormatVersion
        else {
            throw AppError.importFailed
        }

        if mode == .replace {
            try BackupStore.createAutomaticBackup(
                context: context,
                reason: "before-restore",
                in: automaticBackupFolder
            )
            try DemoData.clear(context: context)
        }

        if let customCategories = envelope.data.customCategories {
            if mode == .replace {
                CustomCategoryCatalog.shared.replaceAll(customCategories)
            } else {
                CustomCategoryCatalog.shared.merge(customCategories)
            }
        }

        let existingIncomes = try context.fetch(FetchDescriptor<IncomeEntry>())
        let existingExpenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let existingRecurring = try context.fetch(FetchDescriptor<RecurringPayment>())
        let existingSubscriptions = try context.fetch(FetchDescriptor<Subscription>())
        let existingBudgets = try context.fetch(FetchDescriptor<Budget>())
        let existingGoals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let existingPeriods = try context.fetch(FetchDescriptor<PaymentPeriod>())
        let existingDetails = try context.fetch(FetchDescriptor<RecurringDetail>())
        let existingPriceChanges = try context.fetch(FetchDescriptor<RecurringPriceChange>())

        var incomeKeys = Set(existingIncomes.map { incomeKey($0) })
        var expenseKeys = Set(existingExpenses.map { expenseKey($0) })
        var recurringKeys = Set(existingRecurring.map { recurringKey($0) })
        var subscriptionKeys = Set(existingSubscriptions.map { subscriptionKey($0) })
        var budgetKeys = Set(existingBudgets.map { budgetKey($0) })
        var goalKeys = Set(existingGoals.map { $0.name })
        var periodKeys = Set(existingPeriods.map { periodKey($0) })
        var detailKeys = Set(existingDetails.map { $0.recurringKey })
        var priceKeys = Set(existingPriceChanges.map { priceChangeKey($0) })

        var summary = RestoreSummary(mode: mode)

        for item in envelope.data.incomes {
            let key =
                "\(item.date.startOfDay.timeIntervalSince1970)|\(item.amount)|\(item.type)|\(item.employer)|\(item.note)"
            guard mode == .replace || !incomeKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                IncomeEntry(
                    amount: item.amount,
                    date: item.date,
                    type: IncomeType(rawValue: item.type) ?? .other,
                    employer: item.employer,
                    note: item.note
                )
            )
            incomeKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.expenses {
            let key = "\(item.date.startOfDay.timeIntervalSince1970)|\(item.amount)|\(item.category)|\(item.note)"
            guard mode == .replace || !expenseKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                ExpenseEntry(
                    amount: item.amount,
                    date: item.date,
                    category: ExpenseCategory(rawValue: item.category) ?? .other,
                    note: item.note
                )
            )
            expenseKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.recurring {
            let key = "\(item.title)|\(item.category)|\(item.baseAmount)"
            guard mode == .replace || !recurringKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            let payment = RecurringPayment(
                title: item.title,
                category: ExpenseCategory(rawValue: item.category) ?? .other,
                baseAmount: item.baseAmount,
                rounding: RoundingRule(rawValue: item.rounding) ?? .none,
                roundingStep: item.roundingStep,
                frequency: PaymentFrequency(rawValue: item.frequency) ?? .monthly,
                dayOfMonth: item.dayOfMonth,
                startDate: item.startDate,
                isActive: item.isActive,
                note: item.note
            )
            context.insert(payment)
            recurringKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.periods ?? [] {
            let key = "\(item.recurringKey)|\(item.periodStart.timeIntervalSince1970)"
            guard mode == .replace || !periodKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                PaymentPeriod(
                    recurringKey: item.recurringKey,
                    periodStart: item.periodStart,
                    status: PaymentStatus(rawValue: item.status) ?? .scheduled,
                    plannedAmount: item.plannedAmount,
                    paidAmount: item.paidAmount,
                    paidDate: item.paidDate,
                    title: item.title,
                    note: item.note
                )
            )
            periodKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.recurringDetails ?? [] {
            guard mode == .replace || !detailKeys.contains(item.recurringKey) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                RecurringDetail(
                    recurringKey: item.recurringKey,
                    endDate: item.endDate,
                    autoPay: item.autoPay,
                    note: item.note
                )
            )
            detailKeys.insert(item.recurringKey)
            summary.inserted += 1
        }

        for item in envelope.data.priceChanges ?? [] {
            let key = "\(item.recurringKey)|\(item.effectiveDate.timeIntervalSince1970)|\(item.amount)"
            guard mode == .replace || !priceKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                RecurringPriceChange(
                    recurringKey: item.recurringKey,
                    effectiveDate: item.effectiveDate,
                    amount: item.amount,
                    note: item.note
                )
            )
            priceKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.subscriptions {
            let key = "\(item.name)|\(item.amount)|\(item.cycle)"
            guard mode == .replace || !subscriptionKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                Subscription(
                    name: item.name,
                    amount: item.amount,
                    cycle: SubscriptionCycle(rawValue: item.cycle) ?? .monthly,
                    startDate: item.startDate,
                    isActive: item.isActive,
                    note: item.note,
                    icon: item.icon,
                    tint: TintColor(rawValue: item.tint) ?? .purple
                )
            )
            subscriptionKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.budgets ?? [] {
            let key = "\(item.year)|\(item.month)|\(item.category)"
            guard mode == .replace || !budgetKeys.contains(key) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                Budget(
                    category: ExpenseCategory(rawValue: item.category) ?? .other,
                    year: item.year,
                    month: item.month,
                    limit: item.limit,
                    note: item.note
                )
            )
            budgetKeys.insert(key)
            summary.inserted += 1
        }

        for item in envelope.data.goals ?? [] {
            guard mode == .replace || !goalKeys.contains(item.name) else {
                summary.skipped += 1
                continue
            }
            context.insert(
                SavingsGoal(
                    name: item.name,
                    target: item.target,
                    saved: item.saved,
                    deadline: item.deadline,
                    note: item.note,
                    isActive: item.isActive
                )
            )
            goalKeys.insert(item.name)
            summary.inserted += 1
        }

        try Persistence.save(context, operation: "backup.restore")
        return summary
    }

    // MARK: - Ключи для merge

    private static func incomeKey(_ entry: IncomeEntry) -> String {
        "\(entry.date.startOfDay.timeIntervalSince1970)|\(entry.amount)|\(entry.type.rawValue)|\(entry.employer)|\(entry.note)"
    }

    private static func expenseKey(_ entry: ExpenseEntry) -> String {
        "\(entry.date.startOfDay.timeIntervalSince1970)|\(entry.amount)|\(entry.category.rawValue)|\(entry.note)"
    }

    private static func recurringKey(_ payment: RecurringPayment) -> String {
        "\(payment.title)|\(payment.category.rawValue)|\(payment.baseAmount)"
    }

    private static func subscriptionKey(_ subscription: Subscription) -> String {
        "\(subscription.name)|\(subscription.amount)|\(subscription.cycle.rawValue)"
    }

    private static func priceChangeKey(_ change: RecurringPriceChange) -> String {
        "\(change.recurringKey)|\(change.effectiveDate.timeIntervalSince1970)|\(change.amount)"
    }

    private static func periodKey(_ period: PaymentPeriod) -> String {
        "\(period.recurringKey)|\(period.periodStart.timeIntervalSince1970)"
    }

    private static func budgetKey(_ budget: Budget) -> String {
        "\(budget.year)|\(budget.month)|\(budget.category.rawValue)"
    }
}
