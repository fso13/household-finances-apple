import Foundation

// MARK: - Оповещения о превышении бюджета

package struct BudgetAlert: Identifiable {
    package let id: String
    package let message: String
    package let title: String

    package init(month: Date, progress: BudgetProgress) {
        id = "budget-\(month.year)-\(month.month)-\(progress.category.rawValue)"
        title = "Бюджет превышен: \(progress.category.title)"
        message = "Потрачено \(Fmt.money(progress.spent)) из \(Fmt.money(progress.limit))."
    }
}

package enum BudgetAlertService {
    package static func alerts(
        for progress: [BudgetProgress],
        month: Date
    ) -> [BudgetAlert] {
        progress
            .filter(\.isOver)
            .map { BudgetAlert(month: month, progress: $0) }
    }
}
