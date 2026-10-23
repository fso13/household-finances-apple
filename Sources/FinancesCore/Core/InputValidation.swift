import Foundation

// MARK: - Проверка ввода

package enum InputValidation {
    package static let maxAmount: Double = 1_000_000_000
    package static let maxTitleLength = 120
    package static let maxNoteLength = 500

    package static func amountError(_ value: Double) -> String? {
        guard value.isFinite else { return "Сумма должна быть числом." }
        guard value > 0 else { return "Сумма должна быть больше нуля." }
        guard value <= maxAmount else { return "Сумма слишком большая." }
        return nil
    }

    package static func entryDateError(_ date: Date, now: Date = Date()) -> String? {
        if date.startOfDay > now.startOfDay {
            return "Дата не может быть в будущем."
        }
        if date.year < 2000 {
            return "Дата слишком старая."
        }
        return nil
    }

    package static func startDateError(_ date: Date, now: Date = Date()) -> String? {
        if date.year < 2000 {
            return "Дата слишком старая."
        }
        if date > now.addingYears(20) {
            return "Дата слишком далеко в будущем."
        }
        return nil
    }

    package static func titleError(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Название не может быть пустым." }
        if trimmed.count > maxTitleLength { return "Название слишком длинное." }
        return nil
    }

    package static func noteError(_ note: String) -> String? {
        note.count > maxNoteLength ? "Комментарий слишком длинный." : nil
    }

    package static func roundingStepError(_ step: Double) -> String? {
        guard step.isFinite, step >= 1, step <= 100_000 else {
            return "Шаг округления должен быть от 1 до 100 000 ₽."
        }
        return nil
    }
}

package extension Date {
    func addingYears(_ value: Int) -> Date {
        calendar.date(byAdding: .year, value: value, to: self) ?? self
    }
}
