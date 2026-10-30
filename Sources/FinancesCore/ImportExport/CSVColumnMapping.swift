import Foundation

// MARK: - Таблица CSV

package struct CSVTable: Identifiable, Sendable {
    package let id = UUID()
    package let name: String
    /// Все строки файла, включая возможную шапку.
    package let allRows: [[String]]

    package init(name: String, allRows: [[String]]) {
        self.name = name
        self.allRows = allRows
    }

    /// Удобный инициализатор для тестов и предпросмотра.
    package init(name: String, headers: [String], rows: [[String]]) {
        self.name = name
        self.allRows = [headers] + rows
    }

    package var headers: [String] { allRows.first ?? [] }
    package var columnCount: Int { allRows.map(\.count).max() ?? 0 }
    package var rowCount: Int { max(0, allRows.count - 1) }

    package func dataRows(hasHeader: Bool) -> ArraySlice<[String]> {
        hasHeader ? allRows.dropFirst() : allRows[...]
    }

    package static func load(data: Data, name: String) throws -> CSVTable {
        let rows = try CSVCodec.parse(data)
        guard !rows.isEmpty else { throw AppError.importFailed }
        return CSVTable(name: name, allRows: rows)
    }
}

// MARK: - Маппинг полей приложения

package enum CSVImportKind: String, CaseIterable, Identifiable, Sendable {
    case income
    case expense
    case mixed

    package var id: String { rawValue }
    package var title: String {
        switch self {
        case .income: "Доходы"
        case .expense: "Расходы"
        case .mixed: "Доходы и расходы"
        }
    }
}

/// Поля приложения. Для дохода используются 5, для расхода — 4.
package struct CSVFieldMapping: Equatable, Sendable {
    package var date: Int?
    package var amount: Int?
    package var type: Int?
    package var employer: Int?
    package var category: Int?
    package var note: Int?
}

package struct CSVColumnMapping: Equatable, Sendable {
    package var hasHeader: Bool = true
    package var kind: CSVImportKind = .mixed
    package var income = CSVFieldMapping()
    package var expense = CSVFieldMapping()
    package var direction: Int?
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

        let date = first(["дата"])
        let amount =
            normalized.firstIndex { $0.contains("сумма в валюте операции") }
            ?? first(["сумма", "amount"])
        let direction = first(["списание/зачисление", "направление", "дебет/кредит"])
        let category = first(["категория", "category"])
        let description = first(["наименование операции", "описание", "назначение"])
        let merchant = first(["наименование тсп", "контрагент", "получатель"])
        let comment = first(["комментарий", "примечание", "comment"])
        let type = first(["тип операции", "тип выплаты"])
        let employer = first(["работодатель", "employer"])
        let status = first(["статус", "status"])

        var mapping = CSVColumnMapping()
        mapping.hasHeader = true
        mapping.kind = direction == nil ? .expense : .mixed
        mapping.direction = direction
        mapping.status = status
        mapping.income = CSVFieldMapping(
            date: date,
            amount: amount,
            type: type,
            employer: description ?? employer,
            category: nil,
            note: comment ?? description
        )
        mapping.expense = CSVFieldMapping(
            date: date,
            amount: amount,
            type: nil,
            employer: nil,
            category: category,
            note: description ?? comment ?? merchant
        )
        return mapping
    }
}

// MARK: - Импорт по маппингу

package enum CSVColumnImporter {
    package static func preview(
        table: CSVTable,
        mapping: CSVColumnMapping
    ) throws -> CSVImportPreview {
        switch mapping.kind {
        case .income:
            guard mapping.income.date != nil, mapping.income.amount != nil else {
                throw AppError.validation("Укажите дату и сумму для доходов.")
            }
        case .expense:
            guard mapping.expense.date != nil, mapping.expense.amount != nil else {
                throw AppError.validation("Укажите дату и сумму для расходов.")
            }
        case .mixed:
            guard mapping.income.date != nil, mapping.income.amount != nil,
                mapping.expense.date != nil, mapping.expense.amount != nil
            else {
                throw AppError.validation("Укажите дату и сумму для доходов и расходов.")
            }
            guard mapping.direction != nil else {
                throw AppError.validation("Для смешанного импорта укажите колонку «Списание/Зачисление».")
            }
        }

        var incomes: [IncomeBackup] = []
        var expenses: [ExpenseBackup] = []
        var rows: [CSVPreviewRow] = []
        var errors: [String] = []
        var skippedSections = 0

        for (offset, row) in table.dataRows(hasHeader: mapping.hasHeader).enumerated() {
            let lineNumber = offset + (mapping.hasHeader ? 2 : 1)

            if let statusIndex = mapping.status,
                let status = value(statusIndex, row)?.lowercased(),
                status.contains("отмен") || status.contains("отклон") || status.contains("не выполн")
            {
                skippedSections += 1
                continue
            }

            let directionText = value(mapping.direction, row)?.lowercased() ?? ""
            let isIncome: Bool
            switch mapping.kind {
            case .income:
                isIncome = true
            case .expense:
                isIncome = false
            case .mixed:
                if directionText.contains("зачисл") || directionText.contains("поступ")
                    || directionText.contains("credit")
                {
                    isIncome = true
                } else if directionText.contains("спис") || directionText.contains("дебет")
                    || directionText.contains("debit")
                {
                    isIncome = false
                } else {
                    errors.append("Строка \(lineNumber): не удалось определить направление операции.")
                    continue
                }
            }

            let fields = isIncome ? mapping.income : mapping.expense
            guard let dateValue = value(fields.date, row), let date = CSVCodec.parseDate(dateValue),
                let amountValue = value(fields.amount, row), let signedAmount = CSVCodec.parseNumber(amountValue)
            else {
                errors.append("Строка \(lineNumber): не удалось прочитать дату или сумму.")
                continue
            }

            let amount = abs(signedAmount)
            guard amount > 0 else { continue }

            let note = value(fields.note, row) ?? ""
            let typeText = isIncome ? (value(fields.type, row) ?? "") : ""
            let categoryText = isIncome ? "" : (value(fields.category, row) ?? "")
            let transferText = [note, categoryText, typeText, directionText]
                .joined(separator: " ")
                .lowercased()
            if mapping.skipTransfers,
                categoryText.lowercased().contains("между счетами")
                    || transferText.contains("перевод между")
                    || transferText.contains("внутренний перевод")
            {
                skippedSections += 1
                continue
            }

            if isIncome {
                let employer = value(fields.employer, row) ?? ""
                let type = incomeType(value: typeText, note: "\(note) \(employer)")
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
                let category = expenseCategory(title: categoryText, note: note)
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
