import Foundation

// MARK: - Импорт банковских выписок OFX

package enum OFXImporter {
    package static func preview(data: Data) throws -> CSVImportPreview {
        let text = decode(data)
        guard
            text.localizedCaseInsensitiveContains("<OFX")
                || text.localizedCaseInsensitiveContains("OFXHEADER")
        else {
            throw AppError.importFailed
        }

        let blocks = transactionBlocks(in: text)
        var incomes: [IncomeBackup] = []
        var expenses: [ExpenseBackup] = []
        var rows: [CSVPreviewRow] = []
        var errors: [String] = []
        var seen: Set<String> = []

        for (index, block) in blocks.enumerated() {
            let lineNumber = index + 1
            let type = value("TRNTYPE", in: block)?.uppercased() ?? ""
            guard let rawDate = value("DTPOSTED", in: block),
                let date = parseDate(rawDate)
            else {
                errors.append("Операция \(lineNumber): не удалось прочитать дату.")
                continue
            }
            guard let rawAmount = value("TRNAMT", in: block),
                let amount = parseAmount(rawAmount),
                abs(amount) > 0.004
            else {
                errors.append("Операция \(lineNumber): не удалось прочитать сумму.")
                continue
            }

            let name = value("NAME", in: block) ?? ""
            let memo = value("MEMO", in: block) ?? ""
            let note = [name, memo]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " · ")
            let fitID = value("FITID", in: block) ?? "\\(date.timeIntervalSince1970)|\\(amount)|\\(note)"
            guard seen.insert(fitID).inserted else { continue }

            let isCredit = amount > 0 || type == "CREDIT" || type == "DEP"
            if isCredit {
                let lower = note.lowercased()
                let incomeType: IncomeType =
                    lower.contains("зарплат") || lower.contains("salary") ? .salary : .other
                incomes.append(
                    IncomeBackup(
                        amount: abs(amount),
                        date: date,
                        type: incomeType.rawValue,
                        employer: name,
                        note: note
                    )
                )
                if rows.count < 10 {
                    rows.append(
                        CSVPreviewRow(
                            date: date,
                            title: "Доход",
                            kind: "Доход · \\(incomeType.title)",
                            amount: abs(amount),
                            note: note
                        )
                    )
                }
            } else {
                let category = CategoryRuleEngine.category(for: note) ?? .other
                expenses.append(
                    ExpenseBackup(
                        amount: abs(amount),
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
                            kind: "Расход · \\(category.title)",
                            amount: abs(amount),
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
            skippedSections: 0
        )
    }

    // MARK: - Разбор

    private static func decode(_ data: Data) -> String {
        for encoding in [String.Encoding.utf8, .windowsCP1251, .isoLatin1] {
            if let text = String(data: data, encoding: encoding) {
                return text
            }
        }
        return ""
    }

    private static func transactionBlocks(in text: String) -> [String] {
        let pattern = #"(?is)<STMTTRN(?!RS)[^>]*>(.*?)(?=<STMTTRN(?!RS)[^>]*>|</BANKTRANLIST>|</STMTTRN>)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let blockRange = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[blockRange])
        }
    }

    private static func value(_ tag: String, in block: String) -> String? {
        let pattern = "(?is)<\(tag)>\\s*([^<\r\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(block.startIndex..<block.endIndex, in: block)
        guard let match = regex.firstMatch(in: block, range: range),
            let valueRange = Range(match.range(at: 1), in: block)
        else { return nil }
        return String(block[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let digits = raw.prefix(8)
        guard digits.count == 8 else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: String(digits))
    }

    private static func parseAmount(_ raw: String) -> Double? {
        Double(raw.replacingOccurrences(of: ",", with: "."))
    }
}
