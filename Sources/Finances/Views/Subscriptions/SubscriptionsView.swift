import Charts
import SwiftData
import SwiftUI

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]

    @State private var editor: EditorContext?
    @State private var pendingDelete: Subscription?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let subscription: Subscription?
    }

    private var active: [Subscription] {
        subscriptions.filter(\.isActive)
    }

    private var monthlyTotal: Double {
        Stats.subscriptionMonthlyTotal(subscriptions)
    }

    private var yearlyTotal: Double {
        Stats.total(active.map(\.yearlyCost))
    }

    private var sortedByCost: [Subscription] {
        active.sorted { $0.monthlyCost > $1.monthlyCost }
    }

    private var upcoming: [Subscription] {
        active.sorted { $0.nextPaymentDate < $1.nextPaymentDate }
    }

    private var slices: [CategorySlice] {
        Stats.subscriptionSlices(subscriptions)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary

                if subscriptions.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "repeat.circle",
                            title: "Пока нет подписок",
                            message: "Добавьте сервисы, за которые списывают деньги каждый месяц или год, — приложение посчитает месячную и годовую нагрузку.",
                            actionTitle: "Добавить подписку"
                        ) {
                            editor = EditorContext(subscription: nil)
                        }
                        .frame(height: 300)
                    }
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 16) {
                            structureCard
                                .frame(minWidth: 360, maxWidth: .infinity)
                            upcomingCard
                                .frame(minWidth: 300, maxWidth: 380)
                        }
                        VStack(spacing: 16) {
                            structureCard
                            upcomingCard
                        }
                    }

                    listCard
                }
            }
            .padding(20)
        }
        .navigationTitle("Подписки")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = EditorContext(subscription: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Добавить подписку")
            }
        }
        .sheet(item: $editor) { editorContext in
            SubscriptionEditorSheet(existing: editorContext.subscription)
        }
        .alert(
            "Удалить подписку?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { subscription in
            Button("Удалить", role: .destructive) {
                context.delete(subscription)
                pendingDelete = nil
                try? context.save()
            }
            Button("Отмена", role: .cancel) {
                pendingDelete = nil
            }
        } message: { subscription in
            Text("«\(subscription.name)» будет удалена. Уже записанные расходы останутся.")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Подписки в месяц",
                value: Fmt.moneyRounded(monthlyTotal),
                subtitle: Fmt.plural(active.count, one: "активная подписка", few: "активные подписки", many: "активных подписок"),
                icon: "repeat.circle.fill",
                tint: .purple
            )
            StatCard(
                title: "В год",
                value: Fmt.moneyRounded(yearlyTotal),
                subtitle: "если ничего не менять",
                icon: "calendar.badge.clock",
                tint: .indigo
            )
            StatCard(
                title: "Доля подписок",
                value: averageShareText,
                subtitle: "от средних расходов в месяц",
                icon: "chart.pie.fill",
                tint: .pink
            )
            StatCard(
                title: "Самая дорогая",
                value: sortedByCost.first.map { Fmt.moneyRounded($0.monthlyCost) } ?? "—",
                subtitle: sortedByCost.first?.name ?? "нет активных подписок",
                icon: "crown.fill",
                tint: .orange
            )
        }
    }

    private var averageShareText: String {
        let monthCount = Set(expenses.map { $0.date.startOfMonth }).count
        guard monthCount > 0 else { return "—" }
        let averageMonthlyExpense = Stats.total(expenses.map(\.amount)) / Double(monthCount)
        guard averageMonthlyExpense > 0 else { return "—" }
        return Fmt.percent(monthlyTotal / averageMonthlyExpense)
    }

    private var next30Total: Double {
        let limit = Date().startOfDay.addingDays(30)
        return Stats.total(active.filter { $0.nextPaymentDate <= limit }.map(\.amount))
    }

    private var structureCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Структура подписок",
                    subtitle: "стоимость за год",
                    icon: "chart.pie.fill",
                    tint: .purple
                )

                if slices.isEmpty {
                    EmptyChartView(text: "Нет активных подписок")
                        .frame(height: 190)
                } else {
                    HStack(spacing: 16) {
                        DonutChart(slices: slices, centerTitle: "В год", height: 170)
                            .frame(width: 170)
                        LegendList(slices: slices, maxRows: 7)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var upcomingCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Ближайшие списания",
                    subtitle: "по датам продления",
                    icon: "calendar",
                    tint: .blue
                )

                if upcoming.isEmpty {
                    EmptyChartView(text: "Нет активных подписок")
                        .frame(height: 170)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(upcoming.prefix(5))) { subscription in
                            HStack(spacing: 10) {
                                IconTile(symbol: subscription.icon, tint: subscription.tint.color, size: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(subscription.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Text("\(Fmt.money(subscription.amount)) \(subscription.cycle.shortTitle)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Spacer(minLength: 6)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(MonthFormat.compactDay(subscription.nextPaymentDate))
                                        .font(.caption)
                                        .monospacedDigit()
                                    Text(relativePayment(subscription.nextPaymentDate))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Divider()

                        HStack {
                            Text("В ближайшие 30 дней")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(Fmt.moneyRounded(next30Total))
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var listCard: some View {
        CardView(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    SectionHeader(
                        title: "Все подписки",
                        subtitle: "\(subscriptions.count) всего, \(active.count) активных",
                        icon: "list.bullet",
                        tint: .teal
                    )
                    Spacer()
                    Text("\(Fmt.moneyRounded(monthlyTotal)) / мес. · \(Fmt.moneyRounded(yearlyTotal)) / год")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(16)

                Divider()

                ForEach(subscriptions) { subscription in
                    SubscriptionRow(
                        subscription: subscription,
                        expenses: expenses,
                        onEdit: { editor = EditorContext(subscription: subscription) },
                        onDelete: { pendingDelete = subscription },
                        onRecord: { PaymentRecorder.record(subscription, context: context) }
                    )
                    if subscription.id != subscriptions.last?.id {
                        Divider().padding(.leading, 62)
                    }
                }
            }
        }
    }

    private func relativePayment(_ date: Date) -> String {
        let days = Calendar.current.dateComponents(
            [.day],
            from: Date().startOfDay,
            to: date.startOfDay
        ).day ?? 0

        switch days {
        case ..<0: return "просрочено"
        case 0: return "сегодня"
        case 1: return "завтра"
        default: return "через \(days) дн."
        }
    }
}

// MARK: - Строка списка

private struct SubscriptionRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var subscription: Subscription
    let expenses: [ExpenseEntry]
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRecord: () -> Void

    private var isRecorded: Bool {
        PaymentRecorder.isRecorded(subscription, expenses: expenses, in: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: subscription.icon, tint: subscription.tint.color, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    if isRecorded, subscription.isActive {
                        TagBadge(text: "оплачено", color: .green, icon: "checkmark")
                    }
                }
                Text("\(subscription.cycle.title.lowercased()) · \(Fmt.money(subscription.amount))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Fmt.moneyRounded(subscription.monthlyCost))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
                Text("в месяц · \(Fmt.money(subscription.yearlyCost)) в год")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .frame(minWidth: 150, alignment: .trailing)

            Text(MonthFormat.compactDay(subscription.nextPaymentDate))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 62, alignment: .trailing)

            Toggle("", isOn: $subscription.isActive)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
                .onChange(of: subscription.isActive) { _, _ in
                    try? context.save()
                }

            Button(action: onRecord) {
                Image(systemName: isRecorded ? "checkmark.circle.fill" : "plus.circle")
                    .foregroundStyle(isRecorded ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .disabled(!subscription.isActive || isRecorded)
            .help("Записать списание за этот месяц")

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Изменить")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Удалить")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .opacity(subscription.isActive ? 1 : 0.6)
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Записать списание") { onRecord() }
                .disabled(isRecorded || !subscription.isActive)
            Divider()
            Button("Удалить", role: .destructive) { onDelete() }
        }
    }
}
