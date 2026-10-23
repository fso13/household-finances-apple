import SwiftData
import SwiftUI

struct SubscriptionEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existing: Subscription?
    @State private var draft: SubscriptionDraft

    init(existing: Subscription?) {
        self.existing = existing
        _draft = State(initialValue: SubscriptionDraft(subscription: existing))
    }

    private let icons = [
        "app.fill", "play.tv.fill", "music.note", "icloud.fill",
        "cloud.fill", "brain.head.profile", "book.fill", "paintbrush.fill",
        "gamecontroller.fill", "film.fill", "headphones", "sparkles",
        "newspaper.fill", "photo.fill", "key.fill", "shield.fill",
        "drop.fill", "cart.fill", "figure.run", "graduationcap.fill"
    ]

    private var monthlyCost: Double {
        draft.amount / Double(draft.cycle.months)
    }

    private var nextDate: Date {
        draft.startDate.nextOccurrence(everyMonths: draft.cycle.months, from: draft.startDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                IconTile(symbol: draft.icon, tint: draft.tint.color, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(existing == nil ? "Новая подписка" : "Изменить подписку")
                        .font(.title3.weight(.semibold))
                    Text("Сервис, приложение или регулярная оплата")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(18)

            Divider()

            Form {
                Section("Подписка") {
                    TextField("Название", text: $draft.name, prompt: Text("Например, Яндекс Плюс"))

                    TextField(
                        "Стоимость, ₽",
                        value: $draft.amount,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .monospacedDigit()

                    Picker("Списание", selection: $draft.cycle) {
                        ForEach(SubscriptionCycle.allCases) { cycle in
                            Text(cycle.title).tag(cycle)
                        }
                    }

                    DatePicker("Первый платёж", selection: $draft.startDate, displayedComponents: .date)

                    Toggle("Подписка активна", isOn: $draft.isActive)
                }

                Section("Иконка") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(30), spacing: 6), count: 8),
                        spacing: 6
                    ) {
                        ForEach(icons, id: \.self) { icon in
                            Button {
                                draft.icon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(draft.icon == icon ? Color.white : Color.secondary)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        draft.icon == icon
                                            ? AnyShapeStyle(draft.tint.color)
                                            : AnyShapeStyle(Color.primary.opacity(0.06)),
                                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Цвет") {
                    HStack(spacing: 9) {
                        ForEach(TintColor.allCases) { tint in
                            Button {
                                draft.tint = tint
                            } label: {
                                Circle()
                                    .fill(tint.color)
                                    .frame(width: 18, height: 18)
                                    .padding(3)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(
                                                draft.tint == tint ? Color.primary.opacity(0.65) : .clear,
                                                lineWidth: 2
                                            )
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }

                Section("Итого") {
                    HStack {
                        Text("В месяц")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.moneyRounded(draft.isActive ? monthlyCost : 0))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("В год")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Fmt.money(draft.isActive ? monthlyCost * 12 : 0))
                            .font(.headline)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Следующее списание")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(MonthFormat.day(nextDate))
                            .monospacedDigit()
                    }
                }

                Section("Заметка") {
                    TextField(
                        "Комментарий",
                        text: $draft.note,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Отмена") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(existing == nil ? "Добавить" : "Сохранить") {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(
                    draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || draft.amount <= 0
                )
            }
            .padding(16)
        }
        .frame(width: 500, height: 720)
    }

    private func save() {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing {
            existing.name = name
            existing.amount = draft.amount
            existing.cycle = draft.cycle
            existing.startDate = draft.startDate.startOfDay
            existing.isActive = draft.isActive
            existing.note = draft.note
            existing.icon = draft.icon
            existing.tint = draft.tint
        } else {
            context.insert(Subscription(
                name: name,
                amount: draft.amount,
                cycle: draft.cycle,
                startDate: draft.startDate,
                isActive: draft.isActive,
                note: draft.note,
                icon: draft.icon,
                tint: draft.tint
            ))
        }
        try? context.save()
        dismiss()
    }
}

private struct SubscriptionDraft {
    var name: String = ""
    var amount: Double = 0
    var cycle: SubscriptionCycle = .monthly
    var startDate: Date = .now
    var isActive: Bool = true
    var note: String = ""
    var icon: String = "app.fill"
    var tint: TintColor = .purple

    init(subscription: Subscription?) {
        guard let subscription else { return }
        name = subscription.name
        amount = subscription.amount
        cycle = subscription.cycle
        startDate = subscription.startDate
        isActive = subscription.isActive
        note = subscription.note
        icon = subscription.icon
        tint = subscription.tint
    }
}
