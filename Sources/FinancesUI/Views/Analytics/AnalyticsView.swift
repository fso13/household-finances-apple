import Charts
import SwiftData
import SwiftUI
import FinancesCore

struct AnalyticsView: View {
    @Query private var incomes: [IncomeEntry]
    @Query private var expenses: [ExpenseEntry]

    @State private var selectedYear: Int? = nil
    @State private var selectedQuarter: Int? = nil
    @State private var selectedTypes: Set<IncomeType> = []
    @State private var selectedCategories: Set<ExpenseCategory> = []
    @State private var search = ""
    @State private var comparisonMonth: Date = Date().startOfMonth

    // MARK: - Данные и фильтры

    private var hasData: Bool {
        !incomes.isEmpty || !expenses.isEmpty
    }

    private var availableYears: [Int] {
        Array(Set(incomes.map { $0.date.year } + expenses.map { $0.date.year })).sorted(by: >)
    }

    private var hasActiveFilters: Bool {
        selectedYear != nil
            || selectedQuarter != nil
            || !selectedTypes.isEmpty
            || !selectedCategories.isEmpty
            || !search.isEmpty
    }

    private var filteredIncomes: [IncomeEntry] {
        incomes.filter { entry in
            let matchesYear = selectedYear == nil || entry.date.year == selectedYear
            let matchesQuarter = selectedQuarter == nil || entry.date.quarter == selectedQuarter
            let matchesType = selectedTypes.isEmpty || selectedTypes.contains(entry.type)
            let matchesSearch =
                search.isEmpty
                || entry.note.localizedCaseInsensitiveContains(search)
                || entry.employer.localizedCaseInsensitiveContains(search)
                || entry.type.title.localizedCaseInsensitiveContains(search)
            return matchesYear && matchesQuarter && matchesType && matchesSearch
        }
    }

    private var filteredExpenses: [ExpenseEntry] {
        expenses.filter { entry in
            let matchesYear = selectedYear == nil || entry.date.year == selectedYear
            let matchesQuarter = selectedQuarter == nil || entry.date.quarter == selectedQuarter
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains(entry.category)
            let matchesSearch =
                search.isEmpty
                || entry.note.localizedCaseInsensitiveContains(search)
                || entry.category.title.localizedCaseInsensitiveContains(search)
            return matchesYear && matchesQuarter && matchesCategory && matchesSearch
        }
    }

    private var chartMonths: [Date] {
        if let year = selectedYear {
            if let quarter = selectedQuarter {
                return Stats.monthsInQuarter(year: year, quarter: quarter)
            }
            return Stats.monthsInYear(year)
        }
        let dates = filteredIncomes.map(\.date) + filteredExpenses.map(\.date)
        guard let earliest = dates.min(), let latest = dates.max() else { return [] }
        return Stats.monthSpan(from: earliest, to: latest)
    }

    private var buckets: [MonthBucket] {
        Stats.buckets(incomes: filteredIncomes, expenses: filteredExpenses, months: chartMonths)
    }

    private var totalIncome: Double {
        Stats.total(filteredIncomes.map(\.amount))
    }

    private var totalExpense: Double {
        Stats.total(filteredExpenses.map(\.amount))
    }

    private var net: Double {
        totalIncome - totalExpense
    }

    private var activeIncomeMonths: Int {
        Set(filteredIncomes.map { $0.date.startOfMonth }).count
    }

    private var averageIncome: Double {
        Stats.averageMonthly(total: totalIncome, monthsCount: activeIncomeMonths)
    }

    private var savingsRate: Double {
        Stats.savingsRate(income: totalIncome, expense: totalExpense)
    }

    private var incomeSlices: [CategorySlice] {
        Slices.incomes(filteredIncomes)
    }

    private var expenseSlices: [CategorySlice] {
        Slices.expenses(filteredExpenses)
    }

    private var yearTotals: [YearTotal] {
        Stats.yearTotals(incomes: filteredIncomes, expenses: filteredExpenses)
    }

    private var quarterTotals: [QuarterTotal] {
        Stats.quarterTotals(incomes: filteredIncomes, expenses: filteredExpenses)
    }

    private var comparisonChanges: [CategoryChange] {
        ComparisonService.categoryChanges(
            expenses: expenses,
            currentMonth: comparisonMonth
        )
    }

    private var comparisonCurrent: PeriodTotals {
        ComparisonService.totals(
            incomes: incomes,
            expenses: expenses,
            in: comparisonMonth
        )
    }

    private var comparisonPrevious: PeriodTotals {
        ComparisonService.totals(
            incomes: incomes,
            expenses: expenses,
            in: comparisonMonth.addingMonths(-1)
        )
    }

    private var monthStride: Int {
        chartMonths.count > 18 ? 4 : (chartMonths.count > 10 ? 2 : 1)
    }

    private var maxMonthlyIncome: Double {
        buckets.map(\.income).max() ?? 0
    }

    private var typeAverages: [TypeAverage] {
        IncomeType.allCases.compactMap { type in
            let items = filteredIncomes.filter { $0.type == type }
            guard !items.isEmpty else { return nil }
            let total = Stats.total(items.map(\.amount))
            return TypeAverage(
                type: type,
                count: items.count,
                total: total,
                average: total / Double(items.count)
            )
        }
        .sorted { $0.total > $1.total }
    }

    private struct TypeAverage: Identifiable {
        let type: IncomeType
        let count: Int
        let total: Double
        let average: Double

        var id: String { type.rawValue }
    }

    // MARK: - Вид

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterBar

                if !hasData {
                    CardView {
                        EmptyStateView(
                            icon: "chart.pie",
                            title: "Недостаточно данных",
                            message:
                                "Добавьте доходы и расходы — здесь появятся графики, средние значения и итоги по годам и кварталам."
                        )
                        .frame(height: 320)
                    }
                } else if filteredIncomes.isEmpty && filteredExpenses.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease.circle",
                            title: "Ничего не найдено",
                            message: "Под текущие фильтры не попадает ни одна операция. Попробуйте сбросить фильтры.",
                            actionTitle: "Сбросить фильтры"
                        ) {
                            resetFilters()
                        }
                        .frame(height: 280)
                    }
                } else {
                    kpiRow
                    comparisonCard
                    dynamicsCard

                    HStack(alignment: .top, spacing: 16) {
                        donutCard(
                            title: "Доходы по типам",
                            subtitle: "структура выплат",
                            icon: "arrow.down.circle.fill",
                            tint: .green,
                            slices: incomeSlices
                        )
                        donutCard(
                            title: "Расходы по категориям",
                            subtitle: "куда уходят деньги",
                            icon: "arrow.up.circle.fill",
                            tint: .orange,
                            slices: expenseSlices
                        )
                    }

                    HStack(alignment: .top, spacing: 16) {
                        averageChartCard
                            .frame(maxWidth: .infinity)
                        typeAverageCard
                            .frame(minWidth: 300, maxWidth: 400)
                    }

                    HStack(alignment: .top, spacing: 16) {
                        yearCard
                            .frame(maxWidth: .infinity)
                        quarterCard
                            .frame(minWidth: 300, maxWidth: 420)
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Аналитика")
        .searchable(text: $search, prompt: "Поиск по операциям")
        .onChange(of: selectedYear) { _, newValue in
            if newValue == nil {
                selectedQuarter = nil
            }
        }
    }

    // MARK: - Фильтры

    private var filterBar: some View {
        CardView(padding: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(
                        title: "Фильтры",
                        subtitle: hasActiveFilters ? "применены" : "все данные",
                        icon: "line.3.horizontal.decrease.circle",
                        tint: .indigo
                    )

                    Spacer()

                    if hasData {
                        Text(periodSubtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Button {
                        resetFilters()
                    } label: {
                        Label("Сбросить", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!hasActiveFilters)
                }

                HStack(spacing: 10) {
                    Picker("Год", selection: $selectedYear) {
                        Text("Все годы").tag(Int?.none)
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(Int?.some(year))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 132)
                    .help("Фильтр по году")

                    Picker("Квартал", selection: $selectedQuarter) {
                        Text("Все кварталы").tag(Int?.none)
                        ForEach(1...4, id: \.self) { quarter in
                            Text("\(MonthFormat.romanQuarter(quarter)) квартал").tag(Int?.some(quarter))
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 150)
                    .disabled(selectedYear == nil)
                    .help("Сначала выберите год")

                    Menu {
                        Button("Все типы") { selectedTypes.removeAll() }
                        Divider()
                        ForEach(IncomeType.allCases) { type in
                            Toggle(
                                isOn: Binding(
                                    get: { selectedTypes.contains(type) },
                                    set: { isOn in
                                        if isOn { selectedTypes.insert(type) } else { selectedTypes.remove(type) }
                                    }
                                )
                            ) {
                                Label(type.title, systemImage: type.icon)
                            }
                        }
                    } label: {
                        Label(
                            selectedTypes.isEmpty ? "Все типы" : "Типы: \(selectedTypes.count)",
                            systemImage: "arrow.down.circle"
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 148)
                    .help("Фильтр по типам выплат")

                    Menu {
                        Button("Все категории") { selectedCategories.removeAll() }
                        Divider()
                        ForEach(ExpenseCategory.all) { category in
                            Toggle(
                                isOn: Binding(
                                    get: { selectedCategories.contains(category) },
                                    set: { isOn in
                                        if isOn {
                                            selectedCategories.insert(category)
                                        } else {
                                            selectedCategories.remove(category)
                                        }
                                    }
                                )
                            ) {
                                Label(category.title, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Label(
                            selectedCategories.isEmpty ? "Все категории" : "Категории: \(selectedCategories.count)",
                            systemImage: "arrow.up.circle"
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 176)
                    .help("Фильтр по категориям расходов")

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func resetFilters() {
        selectedYear = nil
        selectedQuarter = nil
        selectedTypes.removeAll()
        selectedCategories.removeAll()
        search = ""
    }

    // MARK: - KPI

    private var kpiRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Доходы",
                value: Fmt.money(totalIncome),
                subtitle: Fmt.plural(filteredIncomes.count, one: "выплата", few: "выплаты", many: "выплат"),
                icon: "arrow.down.circle.fill",
                tint: .green
            )
            StatCard(
                title: "Расходы",
                value: Fmt.money(totalExpense),
                subtitle: Fmt.plural(filteredExpenses.count, one: "запись", few: "записи", many: "записей"),
                icon: "arrow.up.circle.fill",
                tint: .orange
            )
            StatCard(
                title: "Чистый поток",
                value: Fmt.money(net),
                subtitle: "доходы минус расходы",
                icon: "equal.circle.fill",
                tint: net >= 0 ? .teal : .red,
                valueColor: net >= 0 ? .primary : .red
            )
            StatCard(
                title: "Средний доход / мес",
                value: Fmt.moneyRounded(averageIncome),
                subtitle: activeIncomeMonths > 0
                    ? "по \(activeIncomeMonths) мес. · сбережения \(Fmt.percent(savingsRate))"
                    : "нет данных",
                icon: "chart.line.uptrend.xyaxis",
                tint: .indigo
            )
        }
    }

    // MARK: - Динамика

    private var comparisonCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Изменения к прошлому месяцу",
                        subtitle:
                            "\(MonthFormat.monthTitle(comparisonMonth)) к \(MonthFormat.monthTitle(comparisonMonth.addingMonths(-1)))",
                        icon: "arrow.left.arrow.right",
                        tint: .indigo
                    )
                    Spacer()
                    MonthNavigator(month: $comparisonMonth)
                }

                HStack(spacing: 12) {
                    comparisonMetric(
                        "Расходы сейчас",
                        Fmt.moneyRounded(comparisonCurrent.expense),
                        color: .orange
                    )
                    comparisonMetric(
                        "Расходы раньше",
                        Fmt.moneyRounded(comparisonPrevious.expense),
                        color: .secondary
                    )
                    comparisonMetric(
                        "Разница",
                        Fmt.signedMoney(comparisonCurrent.expense - comparisonPrevious.expense),
                        color: comparisonCurrent.expense > comparisonPrevious.expense ? .red : .green
                    )
                    comparisonMetric(
                        "Норма сбережений",
                        Fmt.percent(comparisonCurrent.savingsRate),
                        color: comparisonCurrent.savingsRate >= 0 ? .teal : .red
                    )
                }

                if comparisonChanges.isEmpty {
                    Text("За два месяца нет расходов для сравнения.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(comparisonChanges.prefix(4)) { change in
                        HStack(spacing: 10) {
                            IconTile(
                                symbol: change.category.icon,
                                tint: change.category.color,
                                size: 28
                            )
                            Text(change.category.title)
                                .font(.callout)
                            Spacer()
                            Text("\(Fmt.moneyRounded(change.previous)) → \(Fmt.moneyRounded(change.current))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            TagBadge(
                                text: change.isGrowth
                                    ? "+\(Fmt.moneyRounded(change.delta))"
                                    : Fmt.signedMoney(change.delta),
                                color: change.isGrowth ? .red : .green,
                                icon: change.isGrowth ? "arrow.up.right" : "arrow.down.right"
                            )
                            if let fraction = change.fraction {
                                Text(Fmt.percent(abs(fraction)))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                        if change.id != comparisonChanges.prefix(4).last?.id {
                            Divider().padding(.leading, 38)
                        }
                    }
                }
            }
        }
    }

    private func comparisonMetric(_ title: String, _ value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dynamicsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Динамика доходов и расходов",
                        subtitle: periodSubtitle,
                        icon: "chart.xyaxis.line",
                        tint: .teal
                    )
                    Spacer()
                    HStack(spacing: 12) {
                        legendDot(color: .green, text: "Доходы")
                        legendDot(color: .orange, text: "Расходы")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if buckets.isEmpty {
                    EmptyChartView()
                        .frame(height: 240)
                } else {
                    Chart {
                        ForEach(buckets) { bucket in
                            LineMark(
                                x: .value("Месяц", bucket.month, unit: .month),
                                y: .value("Сумма", bucket.income)
                            )
                            .foregroundStyle(by: .value("Показатель", "Доходы"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))

                            PointMark(
                                x: .value("Месяц", bucket.month, unit: .month),
                                y: .value("Сумма", bucket.income)
                            )
                            .foregroundStyle(by: .value("Показатель", "Доходы"))
                            .symbolSize(22)

                            LineMark(
                                x: .value("Месяц", bucket.month, unit: .month),
                                y: .value("Сумма", bucket.expense)
                            )
                            .foregroundStyle(by: .value("Показатель", "Расходы"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.2))

                            PointMark(
                                x: .value("Месяц", bucket.month, unit: .month),
                                y: .value("Сумма", bucket.expense)
                            )
                            .foregroundStyle(by: .value("Показатель", "Расходы"))
                            .symbolSize(22)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Доходы": Color.green,
                        "Расходы": Color.orange,
                    ])
                    .chartLegend(.hidden)
                    .chartYAxis { compactYAxis() }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: monthStride)) { value in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(
                                        chartMonths.count > 12
                                            ? MonthFormat.shortMonthWithYear(date) : MonthFormat.shortMonth(date)
                                    )
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 260)
                    .accessibilityLabel("Динамика доходов и расходов")
                    .accessibilityValue(
                        "Доходы \(Fmt.money(totalIncome)), расходы \(Fmt.money(totalExpense))"
                    )
                }
            }
        }
    }

    private var periodSubtitle: String {
        if let year = selectedYear {
            if let quarter = selectedQuarter {
                return MonthFormat.quarterTitle(year: year, quarter: quarter)
            }
            return String(year)
        }
        if let first = chartMonths.first, let last = chartMonths.last {
            if first == last {
                return MonthFormat.monthTitle(first)
            }
            return "\(MonthFormat.monthTitle(first)) — \(MonthFormat.monthTitle(last))"
        }
        return "весь период"
    }

    // MARK: - Бублики

    private func donutCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        slices: [CategorySlice]
    ) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: title, subtitle: subtitle, icon: icon, tint: tint)

                if slices.isEmpty {
                    EmptyChartView()
                        .frame(height: 240)
                } else {
                    DonutChart(
                        slices: slices,
                        centerTitle: title.contains("Доходы") ? "Доходы" : "Расходы",
                        height: 190
                    )
                    LegendList(slices: slices, maxRows: 7)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Средние

    private var averageChartCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Средний доход по месяцам",
                    subtitle: averageIncome > 0
                        ? "пунктир — среднее \(Fmt.moneyRounded(averageIncome))"
                        : "пунктир — среднее за период",
                    icon: "chart.bar.fill",
                    tint: .indigo
                )

                if buckets.filter({ $0.income > 0 }).isEmpty {
                    EmptyChartView(text: "Нет доходов за выбранный период")
                        .frame(height: 230)
                } else {
                    Chart {
                        ForEach(buckets.filter { $0.income > 0 }) { bucket in
                            BarMark(
                                x: .value("Месяц", bucket.month, unit: .month),
                                y: .value("Доход", bucket.income)
                            )
                            .foregroundStyle(Color.indigo.gradient)
                            .cornerRadius(4)
                        }

                        if averageIncome > 0 {
                            RuleMark(y: .value("Среднее", averageIncome))
                                .foregroundStyle(Color.orange)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                    }
                    .chartYScale(domain: 0...(maxMonthlyIncome > 0 ? maxMonthlyIncome * 1.25 : 1_000))
                    .chartYAxis { compactYAxis() }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month, count: monthStride)) { value in
                            AxisGridLine().foregroundStyle(.clear)
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(
                                        chartMonths.count > 12
                                            ? MonthFormat.shortMonthWithYear(date) : MonthFormat.shortMonth(date)
                                    )
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 230)
                    .accessibilityLabel("Средний доход по месяцам")
                    .accessibilityValue("Среднее \(Fmt.moneyRounded(averageIncome)) за месяц")
                }
            }
        }
    }

    private var typeAverageCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Средние по типам",
                    subtitle: "сколько в среднем за выплату",
                    icon: "sum",
                    tint: .teal
                )

                if typeAverages.isEmpty {
                    EmptyChartView(text: "Нет выплат")
                        .frame(height: 210)
                } else {
                    VStack(spacing: 10) {
                        ForEach(typeAverages) { row in
                            HStack(spacing: 8) {
                                Image(systemName: row.type.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(row.type.color)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(row.type.title)
                                        .font(.callout)
                                    Text(Fmt.plural(row.count, one: "выплата", few: "выплаты", many: "выплат"))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 6)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(Fmt.moneyRounded(row.average))
                                        .font(.callout.weight(.semibold))
                                        .monospacedDigit()
                                    Text("всего \(Fmt.compact(row.total))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Годы и кварталы

    private var yearCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    SectionHeader(
                        title: "Итоги по годам",
                        subtitle: "доходы и расходы",
                        icon: "calendar",
                        tint: .blue
                    )
                    Spacer()
                    HStack(spacing: 12) {
                        legendDot(color: .green, text: "Доходы")
                        legendDot(color: .orange, text: "Расходы")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if yearTotals.isEmpty {
                    EmptyChartView()
                        .frame(height: 200)
                } else {
                    Chart {
                        ForEach(yearTotals) { item in
                            BarMark(
                                x: .value("Год", String(item.year)),
                                y: .value("Сумма", item.income)
                            )
                            .foregroundStyle(by: .value("Показатель", "Доходы"))
                            .position(by: .value("Показатель", "Доходы"))
                            .cornerRadius(4)

                            BarMark(
                                x: .value("Год", String(item.year)),
                                y: .value("Сумма", item.expense)
                            )
                            .foregroundStyle(by: .value("Показатель", "Расходы"))
                            .position(by: .value("Показатель", "Расходы"))
                            .cornerRadius(4)
                        }
                    }
                    .chartForegroundStyleScale([
                        "Доходы": Color.green,
                        "Расходы": Color.orange,
                    ])
                    .chartLegend(.hidden)
                    .chartYAxis { compactYAxis() }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let year = value.as(String.self) {
                                    Text(year).font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 190)
                    .accessibilityLabel("Доходы и расходы по годам")
                    .accessibilityValue(
                        yearTotals.map {
                            "\($0.year): доходы \(Fmt.money($0.income)), расходы \(Fmt.money($0.expense))"
                        }
                        .joined(separator: "; ")
                    )

                    Divider()

                    VStack(spacing: 6) {
                        yearHeaderRow
                        ForEach(yearTotals.suffix(6)) { item in
                            HStack(spacing: 8) {
                                Text(String(item.year))
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 44, alignment: .leading)
                                Text(Fmt.compact(item.income))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(Fmt.compact(item.expense))
                                    .foregroundStyle(.orange)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text(Fmt.signedCompact(item.net))
                                    .foregroundStyle(item.net >= 0 ? Color.primary : Color.red)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .font(.caption)
                            .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var yearHeaderRow: some View {
        HStack(spacing: 8) {
            Text("Год").frame(width: 44, alignment: .leading)
            Text("Доходы").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Расходы").frame(maxWidth: .infinity, alignment: .trailing)
            Text("Остаток").frame(width: 80, alignment: .trailing)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.tertiary)
    }

    private var quarterCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "По кварталам",
                    subtitle: Fmt.plural(quarterTotals.count, one: "квартал", few: "квартала", many: "кварталов"),
                    icon: "calendar.badge.clock",
                    tint: .purple
                )

                if quarterTotals.isEmpty {
                    EmptyChartView()
                        .frame(height: 200)
                } else {
                    HStack(spacing: 8) {
                        Text("Период").frame(width: 86, alignment: .leading)
                        Text("Доходы").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Расходы").frame(maxWidth: .infinity, alignment: .trailing)
                        Text("Остаток").frame(width: 78, alignment: .trailing)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(quarterTotals) { item in
                                HStack(spacing: 8) {
                                    Text(item.label)
                                        .font(.caption)
                                        .frame(width: 86, alignment: .leading)
                                    Text(Fmt.compact(item.income))
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(Fmt.compact(item.expense))
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text(Fmt.signedCompact(item.net))
                                        .font(.caption)
                                        .foregroundStyle(item.net >= 0 ? Color.primary : Color.red)
                                        .frame(width: 78, alignment: .trailing)
                                }
                                .monospacedDigit()
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 250)
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
}
