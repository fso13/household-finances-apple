import FinancesCore
import SwiftData
import SwiftUI

struct BudgetsView: View {
    @Environment(\.modelContext) private var context

    @Query private var budgets: [Budget]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]

    @State private var month: Date = Date().startOfMonth
    @State private var editor: EditorContext?
    @State private var pendingDelete: Budget?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let budget: Budget?
    }

    private var progress: [BudgetProgress] {
        BudgetService.progress(budgets: budgets, expenses: expenses, month: month)
    }

    private var summary: BudgetSummary {
        BudgetService.summary(progress)
    }

    private var forecast: MonthForecast {
        ForecastService.forecast(
            expenses: expenses,
            month: month,
            categories: Set(progress.map(\.category))
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryRow

                if progress.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "target",
                            title: "Бюджетов на этот месяц нет",
                            message:
                                "Задайте лимит на категорию — приложение покажет, сколько потрачено и сколько осталось.",
                            actionTitle: "Добавить бюджет"
                        ) {
                            editor = EditorContext(budget: nil)
                        }
                        .frame(height: 300)
                    }
                } else {
                    forecastCard

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 340), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(progress) { item in
                            BudgetCard(
                                progress: item,
                                onEdit: {
                                    let budget = BudgetService.budget(
                                        for: item.category,
                                        month: month,
                                        in: budgets
                                    )
                                    editor = EditorContext(budget: budget)
                                },
                                onDelete: {
                                    pendingDelete = BudgetService.budget(
                                        for: item.category,
                                        month: month,
                                        in: budgets
                                    )
                                }
                            )
                        }
                    }

                    Text("Бюджеты задаются на конкретный месяц. Расходы считаются по категории и дате.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(20)
        }
        .navigationTitle("Бюджеты")
        .onAppear {
            BudgetNotificationService.notifyIfNeeded(progress: progress, month: month)
        }
        .onChange(of: notificationSignature) { _, _ in
            BudgetNotificationService.notifyIfNeeded(progress: progress, month: month)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = EditorContext(budget: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Добавить бюджет")
            }
        }
        .sheet(item: $editor) { editorContext in
            BudgetEditorSheet(existing: editorContext.budget, month: month)
        }
        .alert(
            "Удалить бюджет?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { budget in
            Button("Удалить", role: .destructive) {
                do {
                    DeletionUndo.register(budget, in: context)
                    context.delete(budget)
                    try Persistence.save(context, operation: "budget.delete")
                    pendingDelete = nil
                } catch {
                    ErrorCenter.shared.report(error)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingDelete = nil
            }
        } message: { budget in
            Text("Лимит на «\(budget.category.title)» будет удалён. Действие можно отменить через ⌘Z.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(MonthFormat.monthTitle(month))
                    .font(.title2.weight(.bold))
                Text("Лимиты по категориям")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            MonthNavigator(month: $month)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Лимит на месяц",
                value: Fmt.moneyRounded(summary.limit),
                subtitle: Fmt.plural(summary.count, one: "бюджет", few: "бюджета", many: "бюджетов"),
                icon: "target",
                tint: .green
            )
            StatCard(
                title: "Потрачено",
                value: Fmt.moneyRounded(summary.spent),
                subtitle: summary.limit > 0
                    ? "\(Fmt.percent(summary.spent / summary.limit)) лимита"
                    : "нет лимитов",
                icon: "arrow.up.circle.fill",
                tint: .orange
            )
            StatCard(
                title: "Осталось",
                value: Fmt.moneyRounded(summary.remaining),
                subtitle: summary.remaining < 0 ? "перерасход" : "до конца месяца",
                icon: "checkmark.circle.fill",
                tint: summary.remaining < 0 ? .red : .teal,
                valueColor: summary.remaining < 0 ? .red : .primary
            )
            StatCard(
                title: "Без бюджета",
                value: "\(unbudgetedCategoriesCount)",
                subtitle: "категорий с тратами",
                icon: "questionmark.circle.fill",
                tint: .secondary
            )
        }
    }

    private var forecastCard: some View {
        CardView(padding: 14) {
            HStack(spacing: 14) {
                IconTile(symbol: "chart.line.uptrend.xyaxis", tint: .teal, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Прогноз расходов до конца месяца")
                        .font(.callout.weight(.medium))
                    Text(forecastSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(forecast.daysElapsed == 0 ? "—" : Fmt.moneyRounded(forecast.projectedExpense))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.teal)
            }
        }
    }

    private var forecastSubtitle: String {
        if forecast.daysElapsed == 0 {
            return "месяц ещё не начался"
        }
        if forecast.isComplete {
            return "месяц завершён · \(forecast.daysInMonth) дней"
        }
        return
            "средний расход \(Fmt.moneyRounded(forecast.averageDailyExpense)) в день · прошло \(forecast.daysElapsed) из \(forecast.daysInMonth) дней"
    }

    private var notificationSignature: String {
        progress.map { "\($0.id):\($0.spent)" }.joined(separator: "|")
    }

    private var unbudgetedCategoriesCount: Int {
        let used = Set(progress.map(\.category))
        let spentCategories = Set(
            expenses
                .filter { $0.date.isSameMonth(as: month) }
                .map(\.category)
        )
        return spentCategories.subtracting(used).count
    }
}

// MARK: - Карточка бюджета

private struct BudgetCard: View {
    let progress: BudgetProgress
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var tint: Color {
        if progress.isOver { return .red }
        if progress.fraction > 0.85 { return .orange }
        return progress.category.color
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconTile(symbol: progress.category.icon, tint: progress.category.color, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(progress.category.title)
                            .font(.headline)
                        Text("лимит \(Fmt.money(progress.limit))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if progress.isOver {
                        TagBadge(text: "перерасход", color: .red)
                    } else {
                        TagBadge(text: Fmt.percent(progress.fraction), color: tint)
                    }
                }

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(tint)
                            .frame(width: max(0, proxy.size.width * min(progress.fraction, 1)))
                    }
                }
                .frame(height: 8)

                HStack(alignment: .firstTextBaseline) {
                    Text(Fmt.money(progress.spent))
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("из \(Fmt.money(progress.limit))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(
                        progress.isOver
                            ? "превышение \(Fmt.money(abs(progress.remaining)))"
                            : "осталось \(Fmt.money(progress.remaining))"
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(progress.isOver ? .red : .secondary)
                }

                if !progress.note.isEmpty {
                    Text(progress.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Divider()

                HStack {
                    Button {
                        onEdit()
                    } label: {
                        Label("Изменить", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Удалить бюджет")
                    .accessibilityLabel("Удалить бюджет")
                }
            }
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) { onDelete() }
        }
    }
}
