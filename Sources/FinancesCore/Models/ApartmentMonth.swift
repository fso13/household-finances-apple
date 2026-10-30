import Foundation
import SwiftData

// MARK: - Помесячные расходы на квартиру

@Model
package final class ApartmentMonth {
    package var year: Int = 0
    package var month: Int = 1
    package var rentKopecks: Int = 0
    package var capitalRepairKopecks: Int = 0
    package var utilitiesKopecks: Int = 0
    package var electricityKopecks: Int = 0
    package var paidKopecks: Int = 0

    package init(
        year: Int,
        month: Int,
        rent: Double = 0,
        capitalRepair: Double = 0,
        utilities: Double = 0,
        electricity: Double = 0,
        paid: Double = 0
    ) {
        self.year = year
        self.month = month
        self.rentKopecks = Money.kopecks(from: rent)
        self.capitalRepairKopecks = Money.kopecks(from: capitalRepair)
        self.utilitiesKopecks = Money.kopecks(from: utilities)
        self.electricityKopecks = Money.kopecks(from: electricity)
        self.paidKopecks = Money.kopecks(from: paid)
    }

    package var monthStart: Date { Date.make(year: year, month: month) }

    package var rent: Double {
        get { Money.amount(from: rentKopecks) }
        set { rentKopecks = Money.kopecks(from: newValue) }
    }
    package var capitalRepair: Double {
        get { Money.amount(from: capitalRepairKopecks) }
        set { capitalRepairKopecks = Money.kopecks(from: newValue) }
    }
    package var utilities: Double {
        get { Money.amount(from: utilitiesKopecks) }
        set { utilitiesKopecks = Money.kopecks(from: newValue) }
    }
    package var electricity: Double {
        get { Money.amount(from: electricityKopecks) }
        set { electricityKopecks = Money.kopecks(from: newValue) }
    }
    package var paid: Double {
        get { Money.amount(from: paidKopecks) }
        set { paidKopecks = Money.kopecks(from: newValue) }
    }

    package var totalKopecks: Int {
        rentKopecks + capitalRepairKopecks + utilitiesKopecks + electricityKopecks
    }
    package var total: Double { Money.amount(from: totalKopecks) }
    package var overpaymentKopecks: Int { paidKopecks - totalKopecks }
    package var overpayment: Double { Money.amount(from: overpaymentKopecks) }
}
