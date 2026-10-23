import SwiftData
import SwiftUI
import FinancesCore

struct RecurringView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \RecurringPayment.title) private var payments: [RecurringPayment]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]
    @Query private var periods: [PaymentPeriod]
    @Query(sort: \Subscription.name) private var subscriptions: [Subscription]

    @State private var editor: EditorContext?
    @State private var pendingDelete: RecurringPayment?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let payment: RecurringPayment?
    }

    private var activePayments: [RecurringPayment] {
        payments.filter(\.isActive)
    }

    private var sortedPayments: [RecurringPayment] {
        payments.sorted { $0.monthlyCost > $1.monthlyCost }
    }

    private var monthlyTotal: Double {
        Stats.recurringMonthlyTotal(payments)
    }

    private var yearlyTotal: Double {
        Stats.total(activePayments.map(\.yearlyCost))
    }

    private var roundingTotal: Double {
        Stats.roundingAdjustment(payments)
    }

    private var upcoming: [UpcomingPayment] {
        PaymentCalendarService.upcoming(
            payments: payments,
            subscriptions: subscriptions,
            periods: periods,
            expenses: expenses,
            month: Date().startOfMonth
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                roundingHint
                calendarCard

                if payments.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: "Нет обязательных платежей",
                            message:
                                "Добавьте квартиру, гараж, коммуналку или другой регулярный платёж — с суммой и правилом округления.",
                            actionTitle: "Добавить платёж"
                        ) {
                            editor = EditorContext(payment: nil)
                        }
                        .frame(height: 300)
                    }
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 350), spacing: 16, alignment: .top)],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        ForEach(sortedPayments) { payment in
                            RecurringCard(
                                payment: payment,
                                expenses: expenses,
                                periods: periods,
                                onEdit: { editor = EditorContext(payment: payment) },
                                onDelete: { pendingDelete = payment }
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Обязательные платежи")
        .onAppear {
            PaymentReminderService.scheduleIfNeeded(payments: payments, subscriptions: subscriptions)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor = EditorContext(payment: nil)
                } label: {
                    Label("Добавить", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Добавить обязательный платёж")
            }
        }
        .sheet(item: $editor) { editorContext in
            RecurringEditorSheet(existing: editorContext.payment)
        }
        .alert(
            "Удалить обязательный платёж?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { newValue in if !newValue { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { payment in
            Button("Удалить", role: .destructive) {
                do {
                    DeletionUndo.register(payment, in: context)
                    context.delete(payment)
                    try Persistence.save(context, operation: "recurring.delete")
                    pendingDelete = nil
                } catch {
                    ErrorCenter.shared.report(error)
                }
            }
            Button("Отмена", role: .cancel) {
                pendingDelete = nil
            }
        } message: { payment in
            Text("«\(payment.title)» будет удалён из списка регулярных платежей. Уже записанные расходы останутся.")
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Обязательные в месяц",
                value: Fmt.money(monthlyTotal),
                subtitle: Fmt.plural(
                    activePayments.count, one: "активный платёж", few: "активных платежа", many: "активных платежей"),
                icon: "calendar",
                tint: .blue
            )
            StatCard(
                title: "В год",
                value: Fmt.money(yearlyTotal),
                subtitle: "с учётом периодичности",
                icon: "calendar.badge.clock",
                tint: .indigo
            )
            StatCard(
                title: "Округления",
                value: Fmt.signedMoney(roundingTotal.rounded()),
                subtitle: "к базовым суммам в месяц",
                icon: "arrow.up.to.line",
                tint: .orange,
                valueColor: roundingTotal == 0 ? .primary : .orange
            )
            StatCard(
                title: "Всего шаблонов",
                value: "\(payments.count)",
                subtitle: "\(activePayments.count) активных",
                icon: "square.stack.3d.up.fill",
                tint: .teal
            )
        }
    }

    private var calendarCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "Календарь платежей",
                    subtitle: MonthFormat.monthTitle(Date().startOfMonth),
                    icon: "calendar",
                    tint: .teal
                )

                if upcoming.isEmpty {
                    Text("На этот месяц запланированных платежей нет.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                } else {
                    ForEach(upcoming.prefix(6)) { item in
                        HStack(spacing: 12) {
                            VStack(spacing: 0) {
                                Text("\(item.date.day)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                Text(MonthFormat.shortMonth(item.date))
                                    .font(.system(size: 8, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 34, height: 34)
                            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)
                                Text(item.category.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(Fmt.money(item.amount))
                                .font(.callout.weight(.semibold))
                                .monospacedDigit()

                            calendarBadge(item)
                        }
                        if item.id != upcoming.prefix(6).last?.id {
                            Divider().padding(.leading, 46)
                        }
                    }
                }
            }
        }
    }

    private func calendarBadge(_ item: UpcomingPayment) -> some View {
        if item.status == .paid {
            return AnyView(TagBadge(text: "оплачен", color: .green, icon: "checkmark"))
        }
        if item.status == .partial {
            return AnyView(TagBadge(text: "частично", color: .orange, icon: "circle.lefthalf.filled"))
        }
        if item.status == .skipped {
            return AnyView(TagBadge(text: "пропущен", color: .gray, icon: "forward.fill"))
        }
        if item.isOverdue {
            return AnyView(TagBadge(text: "просрочен", color: .red, icon: "exclamationmark"))
        }
        return AnyView(TagBadge(text: "ожидает", color: .blue, icon: "clock"))
    }

    private var roundingHint: some View {
        CardView(padding: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Как работает округление")
                        .font(.callout.weight(.semibold))
                    Text(
                        "Правило применяется к базовой сумме каждого платежа. Например: аренда 47 250 ₽ с округлением вверх до 100 ₽ превращается в 47 300 ₽ — в карточке видно и базу, и надбавку, и итог к оплате."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

// MARK: - Карточка платежа

private struct RecurringCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var payment: RecurringPayment
    let expenses: [ExpenseEntry]
    let periods: [PaymentPeriod]
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showPartial = false
    @State private var partialAmount = ""

    private var month: Date { Date().startOfMonth }

    private var status: PaymentStatus {
        PaymentPeriodService.status(
            for: payment,
            month: month,
            periods: periods,
            expenses: expenses
        )
    }

    private var currentPeriod: PaymentPeriod? {
        PaymentPeriodService.period(for: payment, month: month, periods: periods)
    }

    private var isOverdue: Bool {
        PaymentPeriodService.isOverdue(
            payment,
            month: month,
            periods: periods,
            expenses: expenses
        )
    }

    private var statusBadge: some View {
        if status == .paid {
            TagBadge(text: "оплачено", color: .green, icon: "checkmark")
        } else if status == .partial {
            TagBadge(
                text: "частично \(Fmt.money(currentPeriod?.paidAmount ?? 0))",
                color: .orange,
                icon: "circle.lefthalf.filled"
            )
        } else if status == .skipped {
            TagBadge(text: "пропущен", color: .gray, icon: "forward.fill")
        } else if isOverdue {
            TagBadge(text: "просрочен", color: .red, icon: "exclamationmark")
        } else {
            TagBadge(text: "запланирован", color: .blue, icon: "clock")
        }
    }

    var body: some View {
        CardView(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconTile(symbol: payment.category.icon, tint: payment.category.color, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payment.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text("\(payment.category.title) · \(payment.frequency.title.lowercased())")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 6)
                    Toggle("", isOn: $payment.isActive)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .help(payment.isActive ? "Приостановить платёж" : "Возобновить платёж")
                        .accessibilityLabel(payment.isActive ? "Платёж активен" : "Платёж приостановлен")
                        .onChange(of: payment.isActive) { _, _ in
                            do {
                                try Persistence.save(context, operation: "recurring.toggle")
                            } catch {
                                ErrorCenter.shared.report(error)
                            }
                        }
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Fmt.money(payment.payableAmount))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(payment.isActive ? .primary : .secondary)
                    Text(payment.frequency == .monthly ? "к оплате" : "за \(payment.frequency.shortTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if payment.isActive {
                        statusBadge
                    }
                }

                if payment.rounding != .none {
                    HStack(spacing: 6) {
                        TagBadge(
                            text: "\(payment.rounding.shortTitle.lowercased()) до \(Int(payment.roundingStep)) ₽",
                            color: .orange,
                            icon: payment.rounding.icon
                        )
                        Spacer(minLength: 4)
                        Text("база \(Fmt.money(payment.baseAmount))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        if abs(payment.roundingDelta) >= 0.005 {
                            Text(Fmt.signedMoney(payment.roundingDelta))
                                .font(.caption2.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.orange)
                        }
                    }
                } else {
                    HStack {
                        Text("Без округления")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("база \(Fmt.money(payment.baseAmount))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !payment.note.isEmpty {
                    Text(payment.note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label(
                        "далее \(MonthFormat.compactDay(payment.nextPaymentDate))",
                        systemImage: "calendar"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    if payment.frequency != .monthly {
                        Text("≈ \(Fmt.money(payment.monthlyCost)) / мес.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }

                Divider()

                HStack(spacing: 8) {
                    if status == .skipped, let currentPeriod {
                        Button {
                            do {
                                try PaymentPeriodService.unskip(currentPeriod, context: context)
                            } catch {
                                ErrorCenter.shared.report(error)
                            }
                        } label: {
                            Label("Вернуть в план", systemImage: "arrow.uturn.backward")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Button {
                            do {
                                try PaymentPeriodService.markPaid(
                                    payment,
                                    month: month,
                                    context: context,
                                    periods: periods
                                )
                            } catch {
                                ErrorCenter.shared.report(error)
                            }
                        } label: {
                            Label(
                                status == .paid
                                    ? "Оплачено"
                                    : (status == .partial ? "Доплатить" : "Записать оплату"),
                                systemImage: status == .paid ? "checkmark.circle.fill" : "plus.circle"
                            )
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(!payment.isActive || status == .paid)
                    }

                    if payment.isActive && (status == .scheduled || status == .partial) {
                        Button {
                            partialAmount = ""
                            showPartial = true
                        } label: {
                            Label("Частично", systemImage: "circle.lefthalf.filled")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if status == .scheduled && payment.isActive {
                        Menu {
                            Button("Пропустить месяц", systemImage: "forward.fill") {
                                do {
                                    try PaymentPeriodService.skip(
                                        payment,
                                        month: month,
                                        context: context,
                                        periods: periods
                                    )
                                } catch {
                                    ErrorCenter.shared.report(error)
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("Ещё")
                    }

                    Spacer()

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Изменить")
                    .accessibilityLabel("Изменить платёж")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Удалить")
                    .accessibilityLabel("Удалить платёж")
                }
            }
            .opacity(payment.isActive ? 1 : 0.65)
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) { onDelete() }
        }
        .alert("Частичная оплата", isPresented: $showPartial) {
            TextField("Сумма, ₽", text: $partialAmount)
            Button("Отмена", role: .cancel) {}
            Button("Записать") { recordPartial() }
        } message: {
            Text("Сколько оплачено сейчас? Остаток можно доплатить позже.")
        }
    }

    private func recordPartial() {
        let normalized =
            partialAmount
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalized), amount > 0 else { return }
        do {
            try PaymentPeriodService.recordPartial(
                payment,
                month: month,
                amount: amount,
                context: context,
                periods: periods
            )
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}
