import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers
import FinancesCore

// MARK: - Экспорт в CSV

@MainActor
enum Exporter {
    static func exportCSV(context: ModelContext) throws {
        let incomes: [IncomeEntry]
        let expenses: [ExpenseEntry]
        let recurring: [RecurringPayment]
        let subscriptions: [Subscription]

        do {
            incomes = try context.fetch(FetchDescriptor<IncomeEntry>(sortBy: [SortDescriptor(\.date)]))
            expenses = try context.fetch(FetchDescriptor<ExpenseEntry>(sortBy: [SortDescriptor(\.date)]))
            recurring = try context.fetch(FetchDescriptor<RecurringPayment>(sortBy: [SortDescriptor(\.title)]))
            subscriptions = try context.fetch(FetchDescriptor<Subscription>(sortBy: [SortDescriptor(\.name)]))
        } catch {
            AppLog.export.error("fetch failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }

        var rows: [[String]] = [
            ["Раздел", "Дата", "Тип / категория", "Сумма", "Работодатель", "Примечание"]
        ]

        for income in incomes {
            rows.append([
                "Доход",
                CSVCodec.machineDate(income.date),
                income.type.title,
                CSVCodec.machineNumber(income.amount),
                income.employer,
                income.note,
            ])
        }

        for expense in expenses {
            rows.append([
                "Расход",
                CSVCodec.machineDate(expense.date),
                expense.category.title,
                CSVCodec.machineNumber(expense.amount),
                "",
                expense.note,
            ])
        }

        for payment in recurring {
            rows.append([
                "Обязательный платёж",
                CSVCodec.machineDate(payment.startDate),
                payment.category.title,
                CSVCodec.machineNumber(payment.payableAmount),
                "",
                [
                    payment.title,
                    payment.frequency.title,
                    payment.roundingDescription,
                    payment.note,
                ].filter { !$0.isEmpty }.joined(separator: " · "),
            ])
        }

        for subscription in subscriptions {
            rows.append([
                "Подписка",
                CSVCodec.machineDate(subscription.startDate),
                "Подписки",
                CSVCodec.machineNumber(subscription.amount),
                "",
                [
                    subscription.name,
                    subscription.cycle.title,
                    subscription.isActive ? "активна" : "приостановлена",
                    subscription.note,
                ].filter { !$0.isEmpty }.joined(separator: " · "),
            ])
        }

        let data = CSVCodec.encode(rows: rows, delimiter: ";", bom: true)

        let panel = NSSavePanel()
        panel.title = "Экспорт финансов в CSV"
        panel.nameFieldStringValue = "финансы-\(fileStamp()).csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
        } catch {
            AppLog.export.error("write failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.exportFailed
        }
    }

    enum StatementImport {
        case ofx(CSVImportPreview)
        case csv(CSVTable)
    }

    static func chooseCSV() throws -> StatementImport? {
        let panel = NSOpenPanel()
        panel.title = "Импорт операций из CSV или OFX"
        let ofxType = UTType(filenameExtension: "ofx") ?? .data
        panel.allowedContentTypes = [.commaSeparatedText, .plainText, ofxType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "ofx" || looksLikeOFX(data) {
                return .ofx(try OFXImporter.preview(data: data))
            }
            return .csv(try CSVTable.load(data: data, name: url.lastPathComponent))
        } catch let error as AppError {
            throw error
        } catch {
            AppLog.import.error("csv read failed: \(error.localizedDescription, privacy: .public)")
            throw AppError.importFailed
        }
    }

    private static func looksLikeOFX(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else { return false }
        return text.localizedCaseInsensitiveContains("<OFX")
            || text.localizedCaseInsensitiveContains("OFXHEADER")
    }

    private static func fileStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
