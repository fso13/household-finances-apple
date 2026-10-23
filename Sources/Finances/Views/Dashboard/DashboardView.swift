import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \IncomeEntry.date, order: .reverse) private var incomes: [IncomeEntry]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]
    @Query private var recurring: [RecurringPayment]
    @Query private var subscriptions: [Subscription]

    @State private var month: Date = Date().startOfMonth
    @State private var quickAdd: QuickAddKind?

    private enum QuickAddKind: String, Identifiable {
        case income
        case expense
        var id: String { rawValue }
    }

    // MARK: - Вычисления

    private var monthIncomes: [IncomeEntry] {
        incomes.filter { $0.date.isSameMonth(as: month) }
    }

    private var monthExpenses: [ExpenseEntry] {
        expenses.filter { $0.date.isSameMonth(as: month) }
    }

    private var monthIncomeTotal: Double {
        Stats.total(monthIncomes.map(\.amount))
    }

    private var monthExpenseTotal: Double {
        Stats.total(monthExpenses.map(\.amount))
    }

    private var monthNet: Double {
        monthIncomeTotal - monthExpenseTotal
    }

    private var previousIncomes: [IncomeEntry] {
        incomes.filter { $0.date.isSameMonth(as: month.addingMonths(-1)) }
    }

    private var previousExpenses: [ExpenseEntry] {
        expenses.filter { $0.date.isSameMonth(as: month.addingMonths(-1)) }
    }

    private var twelveMonths: [Date] {
        Stats.monthsEnding(at: month, count: 12)
    }

    private var buckets: [MonthBucket] {
        Stats.buckets(incomes: incomes, expenses: expenses, months: twelveMonths)
    }

    private var averageIncome: Double {
        Stats.total(buckets.map(\.income)) / 12
    }

    private var activeRecurring: [RecurringPayment] {
        recurring.filter(\.isActive).sorted { $0.monthlyCost > $1.monthlyCost }
    }

    private var activeSubscriptions: [Subscription] {
        subscriptions.filter(\.isActive).sorted { $0.monthlyCost > $1.monthlyCost }
    }

    private var recurringMonthly: Double {
        Stats.recurringMonthlyTotal(recurring)
    }

    private var subscriptionsMonthly: Double {
        Stats.subscriptionMonthlyTotal(subscriptions)
    }

    private var expenseSlices: [CategorySlice] {
        Stats.expenseSlices(monthExpenses)
    }

    private var hasAnyData: Bool {
        !incomes.isEmpty || !expenses.isEmpty || !recurring.isEmpty || !subscriptions.isEmpty
    }

    // MARK: - Вид

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if !hasAnyData {
                    CardView {
                        EmptyStateView(
                            icon: "chart.pie",
                            title: "Пока нет данных",
                            message: "Добавьте первую выплату или расход. Демо-данные можно загрузить в настройках.",
                            actionTitle: "Добавить доход"
                        ) {
                            quickAdd = .income
                        }
                        .frame(height: 340)
                    }
                } else {
                    kpiRow

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            cashflowCard
                                .frame(minWidth: 440, maxWidth: .infinity)
                            expenseStructureCard
                                .frame(minWidth: 360, maxWidth: 460)
                        }
                        VStack(spacing: 16) {
                            cashflowCard
                            expenseStructureCard
                        }
                    }

                    HStack(alignment: .top, spacing: 16) {
                        recurringCard
                            .frame(maxWidth: .infinity)
                        subscriptionsCard
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Обзор")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        quickAdd = .income
                    } label: {
                        Label("Добавить доход", systemImage: "arrow.down.circle")
                    }
                    Button {
                        quickAdd = .expense
                    } label: {
                        Label("Добавить расход", systemImage: "arrow.up.circle")
                    }
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
            }
        }
        .sheet(item: $quickAdd) { kind in
            switch kind {
            case .income:
                IncomeEditorSheet(existing: nil)
            case .expense:
                ExpenseEditorSheet(existing: nil)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MonthFormat.monthTitle(month))
                    .font(.title2.weight(.bold))
                Text("Сводка за месяц")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MonthNavigator(month: $month)
        }
    }

    private var kpiRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Доход за месяц",
                value: Fmt.moneyRounded(monthIncomeTotal),
                subtitle: changeText(current: monthIncomeTotal, previous: Stats.total(previousIncomes.map(\.amount))),
                icon: "arrow.down.circle.fill",
                tint: .green
            )

            StatCard(
                title: "Расходы за месяц",
                value: Fmt.moneyRounded(monthExpenseTotal),
                subtitle: "обязательные: \(Fmt.moneyRounded(recurringMonthly))",
                icon: "arrow.up.circle.fill",
                tint: .orange
            )

            StatCard(
                title: "Остаток",
                value: Fmt.moneyRounded(monthNet),
                subtitle: monthIncomeTotal > 0 ? "норма сбережений \(Fmt.percent(monthNet / monthIncomeTotal))" : nil,
                icon: "creditcard.fill",
                tint: monthNet >= 0 ? .teal : .red,
                valueColor: monthNet >= 0 ? .primary : .red
            )

            StatCard(
                title: "Средний доход / мес",
                value: Fmt.moneyRounded(averageIncome),
                subtitle: "за последние 12 месяцев",
                icon: "chart.line.uptrend.xyaxis",
                tint: .indigo
            )
        }
    }

    private var cashflowCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Доходы и расходы",
                        subtitle: "последние 12 месяцев",
                        icon: "chart.bar.xaxis",
                        tint: .indigo
                    )
                    Spacer()
                    HStack(spacing: 12) {
                        legendDot(color: .green, text: "Доходы")
                        legendDot(color: .orange, text: "Расходы")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(buckets) { bucket in
                        BarMark(
                            x: .value("Месяц", bucket.month, unit: .month),
                            y: .value("Сумма", bucket.income)
                        )
                        .foregroundStyle(by: .value("Показатель", "Доходы"))
                        .position(by: .value("Показатель", "Доходы"))
                        .cornerRadius(3)

                        BarMark(
                            x: .value("Месяц", bucket.month, unit: .month),
                            y: .value("Сумма", bucket.expense)
                        )
                        .foregroundStyle(by: .value("Показатель", "Расходы"))
                        .position(by: .value("Показатель", "Расходы"))
                        .cornerRadius(3)
                    }
                }
                .chartForegroundStyleScale([
                    "Доходы": Color.green,
                    "Расходы": Color.orange
                ])
                .chartLegend(.hidden)
                .chartYAxis { compactYAxis() }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month, count: 1)) { value in
                        AxisGridLine().foregroundStyle(.clear)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(MonthFormat.shortMonth(date))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
    }

    private var expenseStructureCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Структура расходов",
                    subtitle: MonthFormat.monthTitle(month).lowercased(),
                    icon: "chart.pie.fill",
                    tint: .orange
                )

                if expenseSlices.isEmpty {
                    EmptyChartView(text: "Расходов за этот месяц нет")
                        .frame(height: 190)
                } else {
                    HStack(spacing: 16) {
                        DonutChart(slices: expenseSlices, centerTitle: "Расходы", height: 158)
                            .frame(width: 158)
                        LegendList(slices: expenseSlices, compact: true, maxRows: 6)
                            .frame(maxWidth: .infinity)
                    }
                }

                Divider()

                SummaryRow(
                    label: "Всего расходов",
                    value: Fmt.moneyRounded(monthExpenseTotal),
                    bold: true
                )
            }
        }
    }

    private var recurringCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Обязательные платежи",
                        subtitle: "квартира, гараж, коммуналка",
                        icon: "calendar.badge.clock",
                        tint: .blue
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Fmt.moneyRounded(recurringMonthly))
                            .font(.callout.weight(.bold))
                            .monospacedDigit()
                        Text("в месяц")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if activeRecurring.isEmpty {
                    emptyHint("Нет обязательных платежей", icon: "calendar.badge.plus")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(activeRecurring.prefix(4))) { payment in
                            HStack(spacing: 10) {
                                IconTile(symbol: payment.category.icon, tint: payment.category.color, size: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(payment.title)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text(payment.frequency.title.lowercased())
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(Fmt.money(payment.payableAmount))
                                        .font(.callout.weight(.medium))
                                        .monospacedDigit()
                                    if abs(payment.roundingDelta) >= 0.005 {
                                        Text("округление \(Fmt.signedMoney(payment.roundingDelta))")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text("В год")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Fmt.moneyRounded(Stats.total(recurring.filter(\.isActive).map(\.yearlyCost))))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    private var subscriptionsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Подписки",
                        subtitle: "\(activeSubscriptions.count) активных сервисов",
                        icon: "repeat.circle.fill",
                        tint: .purple
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Fmt.moneyRounded(subscriptionsMonthly))
                            .font(.callout.weight(.bold))
                            .monospacedDigit()
                        Text("в месяц")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if activeSubscriptions.isEmpty {
                    emptyHint("Активных подписок нет", icon: "repeat")
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(activeSubscriptions.prefix(4))) { subscription in
                            HStack(spacing: 10) {
                                IconTile(symbol: subscription.icon, tint: subscription.tint.color, size: 28)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(subscription.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text("следующее списание \(MonthFormat.compactDay(subscription.nextPaymentDate))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 8)
                                Text(Fmt.moneyRounded(subscription.monthlyCost))
                                    .font(.callout.weight(.medium))
                                    .monospacedDigit()
                            }
                        }
                    }
                }

                Divider()

                HStack {
                    Text("В год")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(Fmt.moneyRounded(Stats.total(activeSubscriptions.map(\.yearlyCost))))
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Вспомогательное

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
        }
    }

    private func emptyHint(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 14)
    }

    private func changeText(current: Double, previous: Double) -> String? {
        guard previous > 0 else { return nil }
        let change = (current - previous) / previous
        if abs(change) < 0.0005 {
            return "как в прошлом месяце"
        }
        return "\(Fmt.signedPercent(change)) к прошлому месяцу"
    }
}
