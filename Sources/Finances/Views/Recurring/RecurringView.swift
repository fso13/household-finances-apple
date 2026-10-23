import SwiftData
import SwiftUI

struct RecurringView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \RecurringPayment.title) private var payments: [RecurringPayment]
    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]

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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                roundingHint

                if payments.isEmpty {
                    CardView {
                        EmptyStateView(
                            icon: "calendar.badge.plus",
                            title: "Нет обязательных платежей",
                            message: "Добавьте квартиру, гараж, коммуналку или другой регулярный платёж — с суммой и правилом округления.",
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
                context.delete(payment)
                pendingDelete = nil
                try? context.save()
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
                subtitle: Fmt.plural(activePayments.count, one: "активный платёж", few: "активных платежа", many: "активных платежей"),
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

    private var roundingHint: some View {
        CardView(padding: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Как работает округление")
                        .font(.callout.weight(.semibold))
                    Text("Правило применяется к базовой сумме каждого платежа. Например: аренда 47 250 ₽ с округлением вверх до 100 ₽ превращается в 47 300 ₽ — в карточке видно и базу, и надбавку, и итог к оплате.")
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
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var isRecorded: Bool {
        PaymentRecorder.isRecorded(payment, expenses: expenses, in: .now)
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
                        .onChange(of: payment.isActive) { _, _ in
                            try? context.save()
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
                    if isRecorded, payment.isActive {
                        TagBadge(text: "оплачено", color: .green, icon: "checkmark")
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
                    Button {
                        PaymentRecorder.record(payment, context: context)
                    } label: {
                        Label(
                            isRecorded ? "Оплачено" : "Записать оплату",
                            systemImage: isRecorded ? "checkmark.circle.fill" : "plus.circle"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(!payment.isActive || isRecorded)

                    Spacer()

                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Изменить")

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Удалить")
                }
            }
            .opacity(payment.isActive ? 1 : 0.65)
        }
        .contextMenu {
            Button("Изменить") { onEdit() }
            Button("Удалить", role: .destructive) { onDelete() }
        }
    }
}
