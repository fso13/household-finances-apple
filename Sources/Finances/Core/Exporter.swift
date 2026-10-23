import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Экспорт в CSV

@MainActor
enum Exporter {
    static func exportCSV(context: ModelContext) {
        let incomes = (try? context.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let expenses = (try? context.fetch(FetchDescriptor<ExpenseEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let recurring = (try? context.fetch(FetchDescriptor<RecurringPayment>(sortBy: [SortDescriptor(\.title)]))) ?? []
        let subscriptions = (try? context.fetch(FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)]))) ?? []

        var rows: [[String]] = [
            ["Раздел", "Дата", "Тип / категория", "Сумма", "Примечание"]
        ]

        for income in incomes {
            rows.append([
                "Доход",
                shortDate(income.date),
                income.type.title,
                Fmt.plain(income.amount, decimals: 2),
                [income.employer, income.note].filter { !$0.isEmpty }.joined(separator: " — ")
            ])
        }

        for expense in expenses {
            rows.append([
                "Расход",
                shortDate(expense.date),
                expense.category.title,
                Fmt.plain(expense.amount, decimals: 2),
                expense.note
            ])
        }

        for payment in recurring {
            rows.append([
                "Обязательный платёж",
                shortDate(payment.startDate),
                payment.category.title,
                Fmt.plain(payment.payableAmount, decimals: 2),
                [
                    payment.title,
                    payment.frequency.title,
                    payment.roundingDescription,
                    payment.note
                ].filter { !$0.isEmpty }.joined(separator: " · ")
            ])
        }

        for subscription in subscriptions {
            rows.append([
                "Подписка",
                shortDate(subscription.startDate),
                "Подписки",
                Fmt.plain(subscription.amount, decimals: 2),
                [
                    subscription.name,
                    subscription.cycle.title,
                    subscription.isActive ? "активна" : "приостановлена",
                    subscription.note
                ].filter { !$0.isEmpty }.joined(separator: " · ")
            ])
        }

        let csv = rows
            .map { row in row.map(escape).joined(separator: ";") }
            .joined(separator: "\r\n")

        let panel = NSSavePanel()
        panel.title = "Экспорт финансов в CSV"
        panel.nameFieldStringValue = "финансы-\(fileStamp()).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let payload = "\u{FEFF}" + csv
            try? payload.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    private static func escape(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
        if cleaned.contains(";") || cleaned.contains("\"") {
            return "\"" + cleaned.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return cleaned
    }

    private static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
