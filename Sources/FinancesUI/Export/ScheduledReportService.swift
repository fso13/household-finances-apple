import FinancesCore
import Foundation
import SwiftData

// MARK: - Отчёты по расписанию

@MainActor
enum ScheduledReportService {
    static let enabledKey = "scheduledReportEnabled"
    static let frequencyKey = "scheduledReportFrequency"
    static let lastGeneratedKey = "scheduledReportLastGenerated"

    static var reportsFolder: URL {
        StoreLocation.folder.appendingPathComponent("Reports", isDirectory: true)
    }

    @discardableResult
    static func runIfNeeded(container: ModelContainer) -> URL? {
        let enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
        guard enabled else { return nil }

        let rawFrequency = UserDefaults.standard.string(forKey: frequencyKey) ?? ReportFrequency.weekly.rawValue
        let frequency = ReportFrequency(rawValue: rawFrequency) ?? .weekly
        let last = UserDefaults.standard.object(forKey: lastGeneratedKey) as? Date

        guard ReportSchedulePlanner.isDue(lastGenerated: last, frequency: frequency) else {
            return nil
        }
        return try? generate(container: container)
    }

    @discardableResult
    static func generate(container: ModelContainer) throws -> URL {
        let context = ModelContext(container)
        let incomes = try context.fetch(FetchDescriptor<IncomeEntry>())
        let expenses = try context.fetch(FetchDescriptor<ExpenseEntry>())
        let months = Stats.monthsEnding(at: Date(), count: 12)
        let buckets = Stats.buckets(incomes: incomes, expenses: expenses, months: months)
        let totalIncome = Stats.total(incomes.filter { months.contains($0.date.startOfMonth) }.map(\.amount))
        let totalExpense = Stats.total(expenses.filter { months.contains($0.date.startOfMonth) }.map(\.amount))

        let data = AnalyticsReportData(
            period: "Последние 12 месяцев",
            income: totalIncome,
            expense: totalExpense,
            net: totalIncome - totalExpense,
            savingsRate: Stats.savingsRate(income: totalIncome, expense: totalExpense),
            topExpenses: Array(Slices.expenses(expenses).prefix(8)),
            monthly: buckets,
            changes: Array(
                ComparisonService.categoryChanges(
                    expenses: expenses,
                    currentMonth: Date().startOfMonth
                ).prefix(5)
            ),
            generatedAt: Date()
        )

        guard let pdf = AnalyticsPDFExporter.pdfData(data) else {
            throw AppError.exportFailed
        }

        try FileManager.default.createDirectory(at: reportsFolder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let url = reportsFolder.appendingPathComponent("Финансы-\(formatter.string(from: Date())).pdf")
        try pdf.write(to: url)
        UserDefaults.standard.set(Date(), forKey: lastGeneratedKey)
        return url
    }
}
