import AppIntents
import FinancesCore
import SwiftData

// MARK: - Shortcuts

struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить расход"
    static var description = IntentDescription("Записывает расход в «Финансы».")

    @Parameter(title: "Сумма")
    var amount: Double

    @Parameter(title: "Категория", description: "Например: Продукты, Транспорт, Квартира")
    var categoryName: String?

    @Parameter(title: "Комментарий")
    var note: String?

    @Parameter(title: "Дата")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = AppBootstrap.shared?.container else {
            throw AppError.storageUnavailable
        }
        guard amount > 0 else {
            throw AppError.validation("Сумма должна быть больше нуля.")
        }

        let note = note ?? ""
        let category =
            ExpenseCategory(title: categoryName ?? "")
            ?? CategoryRuleEngine.category(for: note)
            ?? .other

        let context = ModelContext(container)
        context.insert(
            ExpenseEntry(
                amount: amount,
                date: date ?? Date(),
                category: category,
                note: note
            )
        )
        try Persistence.save(context, operation: "shortcut.expense")
        return .result(dialog: "Расход \(Fmt.money(amount)) записан.")
    }
}

struct AddIncomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Добавить доход"
    static var description = IntentDescription("Записывает доход в «Финансы».")

    @Parameter(title: "Сумма")
    var amount: Double

    @Parameter(title: "Тип", description: "Зарплата, аванс, премия, отпускные и т.д.")
    var typeName: String?

    @Parameter(title: "Работодатель")
    var employer: String?

    @Parameter(title: "Комментарий")
    var note: String?

    @Parameter(title: "Дата")
    var date: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let container = AppBootstrap.shared?.container else {
            throw AppError.storageUnavailable
        }
        guard amount > 0 else {
            throw AppError.validation("Сумма должна быть больше нуля.")
        }

        let type =
            IncomeType.allCases.first {
                $0.title.caseInsensitiveCompare(typeName ?? "") == .orderedSame
                    || $0.rawValue.caseInsensitiveCompare(typeName ?? "") == .orderedSame
            } ?? .other

        let context = ModelContext(container)
        context.insert(
            IncomeEntry(
                amount: amount,
                date: date ?? Date(),
                type: type,
                employer: employer ?? "",
                note: note ?? ""
            )
        )
        try Persistence.save(context, operation: "shortcut.income")
        return .result(dialog: "Доход \(Fmt.money(amount)) записан.")
    }
}

struct FinancesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Добавить расход в \(.applicationName)",
                "Записать расход в \(.applicationName)",
            ],
            shortTitle: "Добавить расход",
            systemImageName: "arrow.up.circle.fill"
        )
        AppShortcut(
            intent: AddIncomeIntent(),
            phrases: [
                "Добавить доход в \(.applicationName)",
                "Записать доход в \(.applicationName)",
            ],
            shortTitle: "Добавить доход",
            systemImageName: "arrow.down.circle.fill"
        )
    }
}
