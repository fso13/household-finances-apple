import Foundation

// MARK: - Теги в заметках

package struct TagCount: Identifiable, Hashable {
    package let tag: String
    package let count: Int

    package var id: String { tag }
}

package enum TagParser {
    /// Извлекает #теги из заметки. Поддерживает кириллицу, цифры, `_` и `-`.
    package static func tags(in text: String) -> Set<String> {
        var result: Set<String> = []
        for token in text.split(whereSeparator: \.isWhitespace) {
            guard token.first == "#" else { continue }
            var tag = ""
            for character in token.dropFirst() {
                if character.isLetter || character.isNumber || character == "_" || character == "-" {
                    tag.append(character)
                } else {
                    break
                }
            }
            if !tag.isEmpty {
                result.insert(tag.lowercased())
            }
        }
        return result
    }

    package static func counts(incomes: [IncomeEntry], expenses: [ExpenseEntry]) -> [TagCount] {
        var counts: [String: Int] = [:]
        for note in incomes.map(\.note) + expenses.map(\.note) {
            for tag in tags(in: note) {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .map { TagCount(tag: $0.key, count: $0.value) }
            .sorted {
                $0.count == $1.count
                    ? $0.tag.localizedCaseInsensitiveCompare($1.tag) == .orderedAscending
                    : $0.count > $1.count
            }
    }

    package static func matches(_ note: String, selected: Set<String>) -> Bool {
        selected.isEmpty || !tags(in: note).isDisjoint(with: selected)
    }
}
