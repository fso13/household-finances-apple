import Foundation
import SwiftData

// MARK: - Импорт CSV

package struct CSVImportPreview: Identifiable, Sendable {
    package let id = UUID()
    package var incomes: [IncomeBackup]
    package var expenses: [ExpenseBackup]
    package var rows: [CSVPreviewRow]
    package var errors: [String]
    package var skippedSections: Int

    package init(
        incomes: [IncomeBackup],
        expenses: [ExpenseBackup],
        rows: [CSVPreviewRow],
        errors: [String],
        skippedSections: Int
    ) {
        self.incomes = incomes
        self.expenses = expenses
        self.rows = rows
        self.errors = errors
        self.skippedSections = skippedSections
    }

    package var totalRows: Int { incomes.count + expenses.count }
}

package struct CSVPreviewRow: Identifiable, Sendable {
    package let id = UUID()
    package var date: Date
    package var title: String
    package var kind: String
    package var amount: Double
    package var note: String
}

package struct CSVImportSummary: Sendable {
    package var inserted: Int
    package var skipped: Int
}

package enum CSVImporter {
    @MainActor
    package static func preview(data: Data) throws -> CSVImportPreview {
        let rows = try CSVCodec.parse(data)
        guard let header = rows.first else {
            throw AppError.importFailed
        }

        let normalized = header.map(normalizedHeader)
        let dateIndex = index(of: ["дата", "date"], in: normalized)
        let amountIndex = index(of: ["сумма", "amount", "стоимость"], in: normalized)
        guard let dateIndex, let amountIndex else {
            throw AppError.importFailed
        }

        let sectionIndex = index(of: ["раздел", "section", "вид"], in: normalized)
        let typeIndex = index(of: ["тип", "type"], in: normalized)
        let categoryIndex = index(of: ["категория", "category"], in: normalized)
        let noteIndex = index(of: ["примечание", "комментарий", "note", "comment"], in: normalized)
        let employerIndex = index(of: ["работодатель", "employer"], in: normalized)

        var incomes: [IncomeBackup] = []
        var expenses: [ExpenseBackup] = []
        var previewRows: [CSVPreviewRow] = []
        var errors: [String] = []
        var skippedSections = 0

        for (offset, row) in rows.dropFirst().enumerated() {
            let lineNumber = offset + 2

            guard let dateValue = value(at: dateIndex, in: row),
                let date = CSVCodec.parseDate(dateValue),
                let amountValue = value(at: amountIndex, in: row),
                let amount = CSVCodec.parseNumber(amountValue),
                amount > 0
            else {
                errors.append("Строка \(lineNumber): не удалось прочитать дату или сумму.")
                continue
            }

            let section = value(at: sectionIndex, in: row)?.lowercased() ?? ""
            let typeValue = value(at: typeIndex, in: row)
            let categoryValue = value(at: categoryIndex, in: row)
            let note = value(at: noteIndex, in: row) ?? ""

            if section.contains("обязательн") || section.contains("подписк") {
                skippedSections += 1
                continue
            }

            let isIncome: Bool
            if section.contains("доход") {
                isIncome = true
            } else if section.contains("расход") {
                isIncome = false
            } else if categoryValue != nil, typeValue == nil {
                isIncome = false
            } else if typeValue != nil, categoryValue == nil {
                isIncome = true
            } else {
                errors.append("Строка \(lineNumber): не удалось определить доход это или расход.")
                continue
            }

            let kindTitle: String
            if isIncome {
                let type = IncomeType(title: typeValue ?? "") ?? .other
                let employer = value(at: employerIndex, in: row) ?? ""
                incomes.append(
                    IncomeBackup(
                        amount: amount,
                        date: date,
                        type: type.rawValue,
                        employer: employer,
                        note: note
                    )
                )
                kindTitle = "Доход · \(type.title)"
            } else {
                let parsed = ExpenseCategory(title: categoryValue ?? "")
                let category =
                    (parsed == nil || parsed == .other)
                    ? (CategoryRuleEngine.category(for: note) ?? parsed ?? .other)
                    : (parsed ?? .other)
                expenses.append(
                    ExpenseBackup(
                        amount: amount,
                        date: date,
                        category: category.rawValue,
                        note: note
                    )
                )
                kindTitle = "Расход · \(category.title)"
            }

            if previewRows.count < 10 {
                previewRows.append(
                    CSVPreviewRow(
                        date: date,
                        title: isIncome ? "Доход" : "Расход",
                        kind: kindTitle,
                        amount: amount,
                        note: note
                    )
                )
            }
        }

        return CSVImportPreview(
            incomes: incomes,
            expenses: expenses,
            rows: previewRows,
            errors: errors,
            skippedSections: skippedSections
        )
    }

    @MainActor
    package static func performImport(
        _ preview: CSVImportPreview,
        context: ModelContext,
        automaticBackupFolder: URL = StoreLocation.backupsFolder
    ) throws -> CSVImportSummary {
        try BackupStore.createAutomaticBackup(
            context: context,
            reason: "before-csv-import",
            in: automaticBackupFolder
        )

        for item in preview.incomes {
            context.insert(
                IncomeEntry(
                    amount: item.amount,
                    date: item.date,
                    type: IncomeType(rawValue: item.type) ?? .other,
                    employer: item.employer,
                    note: item.note
                )
            )
        }

        for item in preview.expenses {
            context.insert(
                ExpenseEntry(
                    amount: item.amount,
                    date: item.date,
                    category: ExpenseCategory(rawValue: item.category) ?? .other,
                    note: item.note
                )
            )
        }

        try Persistence.save(context, operation: "csv.import")
        return CSVImportSummary(inserted: preview.totalRows, skipped: preview.errors.count + preview.skippedSections)
    }

    // MARK: - Заголовки

    private static func normalizedHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
    }

    private static func index(of aliases: [String], in headers: [String]) -> Int? {
        headers.firstIndex { header in aliases.contains(header) }
    }

    private static func value(at index: Int?, in row: [String]) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

// MARK: - Удобные инициализаторы

package extension IncomeType {
    init?(title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        if let exact = IncomeType.allCases.first(where: {
            $0.title.lowercased() == normalized || $0.rawValue == normalized
        }) {
            self = exact
        } else {
            return nil
        }
    }
}

package extension ExpenseCategory {
    init?(title: String) {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return nil }
        if let exact = ExpenseCategory.all.first(where: {
            $0.title.lowercased() == normalized || $0.rawValue == normalized
        }) {
            self = exact
        } else {
            return nil
        }
    }
}
