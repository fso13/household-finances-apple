import Foundation

// MARK: - Таблица CSV и маппинг колонок

package struct CSVTable: Identifiable, Sendable {
    package let id = UUID()
    package let name: String
    package let headers: [String]
    package let rows: [[String]]

    package init(name: String, headers: [String], rows: [[String]]) {
        self.name = name
        self.headers = headers
        self.rows = rows
    }

    package static func load(data: Data, name: String) throws -> CSVTable {
        var parsed = try CSVCodec.parse(data)
        guard let header = parsed.first else { throw AppError.importFailed }
        parsed.removeFirst()
        return CSVTable(name: name, headers: header, rows: parsed)
    }
}

package struct CSVColumnMapping: Equatable, Sendable {
    package var date: Int?
    package var amount: Int?
    package var direction: Int?
    package var category: Int?
    package var description: Int?
    package var merchant: Int?
    package var comment: Int?
    package var incomeType: Int?
    package var employer: Int?
    package var status: Int?
    package var skipTransfers: Bool = true

    package static func automatic(headers: [String]) -> CSVColumnMapping {
        let normalized = headers.map {
            $0.lowercased().replacingOccurrences(of: "ё", with: "е")
        }

        func first(_ aliases: [String]) -> Int? {
            for alias in aliases {
                if let index = normalized.firstIndex(where: { $0.contains(alias) }) {
                    return index
                }
            }
            return nil
        }

        var mapping = CSVColumnMapping()
        mapping.date = first(["дата"])
        mapping.amount =
            normalized.firstIndex { $0.contains("сумма в валюте операции") }
            ?? first(["сумма", "amount"])
        mapping.direction = first(["списание/зачисление", "направление", "дебет/кредит"])
        mapping.category = first(["категория", "category"])
        mapping.description = first(["наименование операции", "описание", "назначение"])
        mapping.merchant = first(["наименование тсп", "контрагент", "получатель"])
        mapping.comment = first(["комментарий", "примечание", "comment"])
        mapping.incomeType = first(["тип операции", "тип выплаты"])
        mapping.employer = first(["работодатель", "employer"])
        mapping.status = first(["статус", "status"])
        return mapping
    }
}

// MARK: - Импорт по маппингу

package enum CSVColumnImporter {
    package static func preview(
        table: CSVTable,
        mapping: CSVColumnMapping
    ) throws -> CSVImportPreview {
        guard let dateIndex = mapping.date, let amountIndex = mapping.amount else {
            throw AppError.validation("Укажите колонки даты и суммы.")
        }

        var incomes: [IncomeBackup] = []
        var expenses: [ExpenseBackup] = []
        var rows: [CSVPreviewRow] = []
        var errors: [String] = []
        var skippedSections = 0

        for (offset, row) in table.rows.enumerated() {
            let lineNumber = offset + 2
            guard let dateValue = value(dateIndex, row), let date = CSVCodec.parseDate(dateValue),
                let amountValue = value(amountIndex, row), let signedAmount = CSVCodec.parseNumber(amountValue)
            else {
                errors.append("Строка \(lineNumber): не удалось прочитать дату или сумму.")
                continue
            }

            if let statusIndex = mapping.status,
                let status = value(statusIndex, row)?.lowercased(),
                status.contains("отмен") || status.contains("отклон") || status.contains("не выполн")
            {
                skippedSections += 1
                continue
            }

            let categoryText = value(mapping.category, row)?.lowercased() ?? ""
            let noteForTransfer = [
                value(mapping.description, row) ?? "",
                value(mapping.merchant, row) ?? "",
                value(mapping.comment, row) ?? "",
                value(mapping.incomeType, row) ?? "",
            ].joined(separator: " ").lowercased()
            if mapping.skipTransfers,
                categoryText.contains("между счетами")
                    || noteForTransfer.contains("перевод между")
                    || noteForTransfer.contains("внутренний перевод")
            {
                skippedSections += 1
                continue
            }

            let amount = abs(signedAmount)
            guard amount > 0 else { continue }

            let directionText = value(mapping.direction, row)?.lowercased() ?? ""
            let isIncome: Bool
            if directionText.contains("зачисл") || directionText.contains("поступ")
                || directionText.contains("credit")
            {
                isIncome = true
            } else if directionText.contains("спис") || directionText.contains("дебет")
                || directionText.contains("debit")
            {
                isIncome = false
            } else {
                isIncome = signedAmount > 0
            }

            let description = value(mapping.description, row) ?? ""
            let merchant = value(mapping.merchant, row) ?? ""
            let comment = value(mapping.comment, row) ?? ""
            let note = [description, merchant, comment]
                .filter { !$0.isEmpty }
                .reduce(into: [String]()) { result, part in
                    guard !result.contains(part) else { return }
                    result.append(part)
                }
                .joined(separator: " · ")

            if isIncome {
                let type = incomeType(
                    value: value(mapping.incomeType, row) ?? "",
                    note: note
                )
                let employer = value(mapping.employer, row) ?? ""
                incomes.append(
                    IncomeBackup(
                        amount: amount,
                        date: date,
                        type: type.rawValue,
                        employer: employer,
                        note: note
                    )
                )
                if rows.count < 10 {
                    rows.append(
                        CSVPreviewRow(
                            date: date,
                            title: "Доход",
                            kind: "Доход · \(type.title)",
                            amount: amount,
                            note: note
                        )
                    )
                }
            } else {
                let category = expenseCategory(
                    title: value(mapping.category, row) ?? "",
                    note: note
                )
                expenses.append(
                    ExpenseBackup(
                        amount: amount,
                        date: date,
                        category: category.rawValue,
                        note: note
                    )
                )
                if rows.count < 10 {
                    rows.append(
                        CSVPreviewRow(
                            date: date,
                            title: "Расход",
                            kind: "Расход · \(category.title)",
                            amount: amount,
                            note: note
                        )
                    )
                }
            }
        }

        return CSVImportPreview(
            incomes: incomes,
            expenses: expenses,
            rows: rows,
            errors: errors,
            skippedSections: skippedSections
        )
    }

    private static func value(_ index: Int?, _ row: [String]) -> String? {
        guard let index, row.indices.contains(index) else { return nil }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func incomeType(value: String, note: String) -> IncomeType {
        if let type = IncomeType(title: value) {
            return type
        }
        let lower = note.lowercased()
        if lower.contains("зарплат") { return .salary }
        if lower.contains("аванс") { return .advance }
        if lower.contains("отпуск") { return .vacation }
        if lower.contains("преми") { return .bonus }
        if lower.contains("больничн") { return .sickLeave }
        return .other
    }

    private static func expenseCategory(title: String, note: String) -> ExpenseCategory {
        if let category = ExpenseCategory(title: title) {
            return category
        }
        if let ruled = CategoryRuleEngine.category(for: "\(title) \(note)") {
            return ruled
        }

        let text = "\(title) \(note)".lowercased()
        if text.contains("супермаркет") || text.contains("продукт") || text.contains("магазин") {
            return .food
        }
        if text.contains("кафе") || text.contains("ресторан") || text.contains("фастфуд") {
            return .food
        }
        if text.contains("такси") || text.contains("транспорт") || text.contains("метро") {
            return .transport
        }
        if text.contains("аптек") || text.contains("здоров") || text.contains("медицин") {
            return .health
        }
        if text.contains("жкх") || text.contains("коммунал") || text.contains("квартплат") {
            return .utilities
        }
        if text.contains("связь") || text.contains("интернет") || text.contains("мобильн") {
            return .internet
        }
        if text.contains("подписк") { return .subscriptions }
        return .other
    }
}
