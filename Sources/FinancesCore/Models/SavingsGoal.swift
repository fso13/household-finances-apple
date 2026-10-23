import Foundation
import SwiftData

// MARK: - Цель накоплений

@Model
package final class SavingsGoal {
    package var uid: UUID = UUID()
    package var name: String = ""
    package var targetKopecks: Int = 0
    package var savedKopecks: Int = 0
    package var deadline: Date?
    package var note: String = ""
    package var isActive: Bool = true

    package init(
        name: String,
        target: Double,
        saved: Double = 0,
        deadline: Date? = nil,
        note: String = "",
        isActive: Bool = true
    ) {
        self.uid = UUID()
        self.name = name
        self.targetKopecks = Money.kopecks(from: target)
        self.savedKopecks = Money.kopecks(from: saved)
        self.deadline = deadline?.startOfDay
        self.note = note
        self.isActive = isActive
    }

    package var target: Double {
        get { Money.amount(from: targetKopecks) }
        set { targetKopecks = Money.kopecks(from: newValue) }
    }

    package var saved: Double {
        get { Money.amount(from: savedKopecks) }
        set { savedKopecks = Money.kopecks(from: newValue) }
    }
}
