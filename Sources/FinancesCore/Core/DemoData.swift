import Foundation
import SwiftData

// MARK: - Демонстрационные данные

@MainActor
package enum DemoData {
    package static func seed(
        context: ModelContext,
        replace: Bool = false,
        referenceDate: Date = Date()
    ) throws {
        if replace {
            try clear(context: context)
        }
        let existing = try context.fetchCount(FetchDescriptor<IncomeEntry>())
        guard existing == 0 else { return }

        let now = referenceDate
        let currentMonth = now.startOfMonth
        let oldestMonth = currentMonth.addingMonths(-23)
        let employer = "ООО «Ромашка»"

        func date(day: Int, in month: Date) -> Date {
            var components = Calendar.current.dateComponents([.year, .month], from: month)
            components.day = min(day, 28)
            return Calendar.current.date(from: components) ?? month
        }

        // Регулярные платежи
        let rent = RecurringPayment(
            title: "Аренда квартиры",
            category: .rent,
            baseAmount: 47_250,
            rounding: .up,
            roundingStep: 100,
            frequency: .monthly,
            dayOfMonth: 10,
            startDate: oldestMonth,
            note: "Арендодатель фиксирует сумму с округлением вверх до 100 ₽."
        )
        let utilities = RecurringPayment(
            title: "Коммуналка",
            category: .utilities,
            baseAmount: 6_347.32,
            rounding: .nearest,
            roundingStep: 10,
            frequency: .monthly,
            dayOfMonth: 15,
            startDate: oldestMonth,
            note: "Считаем по счётчикам, итог округляем до 10 ₽."
        )
        let garage = RecurringPayment(
            title: "Гараж",
            category: .garage,
            baseAmount: 3_300,
            rounding: .up,
            roundingStep: 100,
            frequency: .quarterly,
            dayOfMonth: 5,
            startDate: oldestMonth,
            note: "Оплата раз в квартал, кооператив округляет взнос вверх."
        )
        let internet = RecurringPayment(
            title: "Интернет и мобильная связь",
            category: .internet,
            baseAmount: 1_450,
            rounding: .none,
            roundingStep: 10,
            frequency: .monthly,
            dayOfMonth: 12,
            startDate: oldestMonth,
            note: "Фиксированный тариф, без округления."
        )

        [rent, utilities, garage, internet].forEach(context.insert)

        // Подписки
        let subscriptionSpecs:
            [(name: String, amount: Double, cycle: SubscriptionCycle, tint: TintColor, icon: String, day: Int)] = [
                ("Яндекс Плюс", 399, .monthly, .red, "play.tv.fill", 3),
                ("Apple Music", 199, .monthly, .pink, "music.note", 5),
                ("iCloud+ 200 ГБ", 149, .monthly, .blue, "icloud.fill", 7),
                ("ChatGPT Plus", 2_200, .monthly, .teal, "brain.head.profile", 9),
                ("Литрес", 299, .monthly, .orange, "book.fill", 11),
                ("Figma Pro", 1_800, .monthly, .purple, "paintbrush.fill", 13),
                ("Облако для бэкапов", 7_990, .yearly, .indigo, "cloud.fill", 17),
            ]

        var subscriptions: [Subscription] = []
        for (index, spec) in subscriptionSpecs.enumerated() {
            let subscription = Subscription(
                name: spec.name,
                amount: spec.amount,
                cycle: spec.cycle,
                startDate: oldestMonth.addingMonths(index).addingDays(spec.day - 1),
                note: "",
                icon: spec.icon,
                tint: spec.tint
            )
            context.insert(subscription)
            subscriptions.append(subscription)
        }

        // Доходы
        for index in 0..<24 {
            let month = oldestMonth.addingMonths(index)
            let salary = 150_000 + Double(index / 6) * 10_000
            let advance = (salary * 0.45 / 10).rounded() * 10

            let salaryDate = date(day: 5, in: month)
            if salaryDate <= now {
                context.insert(
                    IncomeEntry(
                        amount: salary,
                        date: salaryDate,
                        type: .salary,
                        employer: employer,
                        note: "Оклад за \(MonthFormat.monthTitle(month).lowercased())"
                    ))
            }

            let advanceDate = date(day: 20, in: month)
            if advanceDate <= now {
                context.insert(
                    IncomeEntry(
                        amount: advance,
                        date: advanceDate,
                        type: .advance,
                        employer: employer,
                        note: "Аванс за \(MonthFormat.monthTitle(month).lowercased())"
                    ))
            }

            if index % 3 == 2 {
                let bonusDate = date(day: 27, in: month)
                if bonusDate <= now {
                    context.insert(
                        IncomeEntry(
                            amount: 45_000 + Double(index % 4) * 5_000,
                            date: bonusDate,
                            type: .bonus,
                            employer: employer,
                            note: "Квартальная премия"
                        ))
                }
            }

            if month.month == 7 {
                let vacationDate = date(day: 14, in: month)
                if vacationDate <= now {
                    context.insert(
                        IncomeEntry(
                            amount: 128_000,
                            date: vacationDate,
                            type: .vacation,
                            employer: employer,
                            note: "Отпускные за 14 дней"
                        ))
                }
            }

            if index == 7 {
                let sickDate = date(day: 9, in: month)
                if sickDate <= now {
                    context.insert(
                        IncomeEntry(
                            amount: 18_400,
                            date: sickDate,
                            type: .sickLeave,
                            employer: employer,
                            note: "Больничный, 5 дней"
                        ))
                }
            }
        }

        // Расходы по регулярным платежам
        for index in 0..<24 {
            let month = oldestMonth.addingMonths(index)

            let rentDate = date(day: rent.dayOfMonth, in: month)
            if rentDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: rent.payableAmount,
                        date: rentDate,
                        category: .rent,
                        note: "Аренда квартиры"
                    ))
            }

            let utilitiesBase = 5_600 + Double((index * 7) % 9) * 130 + 37.32
            let utilitiesAmount = utilities.rounding.apply(utilitiesBase, step: utilities.roundingStep)
            let utilitiesDate = date(day: utilities.dayOfMonth, in: month)
            if utilitiesDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: utilitiesAmount,
                        date: utilitiesDate,
                        category: .utilities,
                        note: "Коммуналка по счётчикам"
                    ))
            }

            if index % 3 == 0 {
                let garageDate = date(day: garage.dayOfMonth, in: month)
                if garageDate <= now {
                    context.insert(
                        ExpenseEntry(
                            amount: garage.payableAmount,
                            date: garageDate,
                            category: .garage,
                            note: "Взнос в гаражный кооператив"
                        ))
                }
            }

            let internetDate = date(day: internet.dayOfMonth, in: month)
            if internetDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: internet.payableAmount,
                        date: internetDate,
                        category: .internet,
                        note: "Интернет и связь"
                    ))
            }

            for (subIndex, subscription) in subscriptions.enumerated() {
                let cyclesPassed = index % subscription.cycle.months
                guard cyclesPassed == 0 else { continue }
                let subscriptionDate = date(day: 3 + subIndex * 2, in: month)
                if subscriptionDate <= now {
                    context.insert(
                        ExpenseEntry(
                            amount: subscription.amount,
                            date: subscriptionDate,
                            category: .subscriptions,
                            note: "Подписка: \(subscription.name)"
                        ))
                }
            }

            let foodDate = date(day: 27, in: month)
            if foodDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: 24_000 + Double((index * 3) % 7) * 1_150,
                        date: foodDate,
                        category: .food,
                        note: "Продукты"
                    ))
            }

            let transportDate = date(day: 18, in: month)
            if transportDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: 4_500 + Double((index * 5) % 4) * 620,
                        date: transportDate,
                        category: .transport,
                        note: "Транспорт и такси"
                    ))
            }

            let funDate = date(day: 21, in: month)
            if funDate <= now {
                context.insert(
                    ExpenseEntry(
                        amount: 3_200 + Double((index * 2) % 5) * 850,
                        date: funDate,
                        category: .entertainment,
                        note: "Кино, кафе, досуг"
                    ))
            }

            if index % 4 == 1 {
                let healthDate = date(day: 14, in: month)
                if healthDate <= now {
                    context.insert(
                        ExpenseEntry(
                            amount: 3_400 + Double(index % 3) * 1_200,
                            date: healthDate,
                            category: .health,
                            note: "Аптека и врач"
                        ))
                }
            }
        }

        let budgetSpecs: [(ExpenseCategory, Double)] = [
            (.food, 30_000),
            (.transport, 8_000),
            (.entertainment, 10_000),
            (.health, 5_000),
        ]
        for (category, limit) in budgetSpecs {
            context.insert(
                Budget(
                    category: category,
                    year: now.year,
                    month: now.month,
                    limit: limit
                )
            )
        }

        context.insert(
            SavingsGoal(
                name: "Финансовая подушка",
                target: 500_000,
                saved: 180_000,
                deadline: now.addingMonths(12),
                note: "Шесть месяцев расходов"
            )
        )
        context.insert(
            SavingsGoal(
                name: "Отпуск",
                target: 150_000,
                saved: 45_000,
                deadline: now.addingMonths(6),
                note: ""
            )
        )

        try Persistence.save(context, operation: "demo.seed")
    }

    package static func clear(context: ModelContext) throws {
        try deleteAll(IncomeEntry.self, context: context)
        try deleteAll(ExpenseEntry.self, context: context)
        try deleteAll(RecurringPayment.self, context: context)
        try deleteAll(Subscription.self, context: context)
        try deleteAll(Budget.self, context: context)
        try deleteAll(SavingsGoal.self, context: context)
        try Persistence.save(context, operation: "demo.clear")
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}
