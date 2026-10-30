import Foundation

// MARK: - CSV

package enum CSVCodec {
    package static func encode(
        rows: [[String]],
        delimiter: Character = ";",
        bom: Bool = true
    ) -> Data {
        let separator = String(delimiter)
        let body =
            rows
            .map { row in row.map { escape($0, delimiter: delimiter) }.joined(separator: separator) }
            .joined(separator: "\r\n")
        let text = (bom ? "\u{FEFF}" : "") + body + "\r\n"
        return Data(text.utf8)
    }

    package static func parse(_ data: Data) throws -> [[String]] {
        var payload = data
        if payload.starts(with: [0xEF, 0xBB, 0xBF]) {
            payload = payload.dropFirst(3)
        }

        guard let text = String(data: payload, encoding: .utf8) else {
            throw AppError.importFailed
        }

        let delimiter = detectDelimiter(in: text)
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == delimiter {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else {
                field.append(character)
            }

            index = text.index(after: index)
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return
            rows
            .map { $0.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } }
            .filter { !$0.allSatisfy(\.isEmpty) }
    }

    // MARK: - Форматирование

    package static func machineDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    package static func machineNumber(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    package static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formats = [
            "yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy",
            "dd.MM.yyyy HH:mm", "dd.MM.yyyy HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ssXXXXX",
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    package static func parseNumber(_ value: String) -> Double? {
        let cleaned =
            value
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "₽", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    // MARK: - Внутреннее

    private static func detectDelimiter(in text: String) -> Character {
        guard let firstLine = text.split(whereSeparator: \.isNewline).first else {
            return ";"
        }
        let candidates: [Character] = [";", ",", "\t"]
        return candidates.max { lhs, rhs in
            firstLine.filter { $0 == lhs }.count < firstLine.filter { $0 == rhs }.count
        } ?? ";"
    }

    private static func escape(_ value: String, delimiter: Character) -> String {
        let needsQuotes =
            value.contains(delimiter)
            || value.contains("\"")
            || value.contains("\n")
            || value.contains("\r")
        guard needsQuotes else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
