import SwiftData
import SwiftUI

struct ExpensesView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \ExpenseEntry.date, order: .reverse) private var expenses: [ExpenseEntry]

    @State private var selectedCategories: Set<ExpenseCategory> = []
    @State private var selectedYear: Int? = nil
    @State private var search = ""
    @State private var selection = Set<PersistentIdentifier>()
    @State private var editor: EditorContext?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let entry: ExpenseEntry?
    }

    private var availableYears: [Int] {
        Array(Set(expenses.map { $0.date.year })).sorted(by: >)
    }

    private var filtered: [ExpenseEntry] {
        expenses.filter { entry in
            let matchesYear = selectedYear == nil || entry.date.year == selectedYear
            let matchesCategory = selectedCategories.isEmpty || selectedCategories.contains(entry.category)
            let matchesSearch = search.isEmpty
                || entry.note.localizedCaseInsensitiveContains(search)
                || entry.category.title.localizedCaseInsensitiveContains(search)
            return matchesYear && matchesCategory && matchesSearch
        }
    }

    private var total: Double {
        Stats.total(filtered.map(\.amount))
    }

    private var mandatoryTotal: Double {
        Stats.total(filtered.filter { $0.category.isMandatory }.map(\.amount))
    }

    private var subscriptionTotal: Double {
        Stats.total(filtered.filter { $0.category == .subscriptions }.map(\.amount))
    }

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            table
        }
        .navigationTitle("Расходы")
        .searchable(text: $search, prompt: "Поиск по расходам")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                yearPicker
                categoryFilter
                editButton
                deleteButton
                addButton
            }
        }
        .sheet(item: $editor) { editorContext in
            ExpenseEditorSheet(existing: editorContext.entry)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Всего",
                value: Fmt.money(total),
                subtitle: Fmt.plural(filtered.count, one: "запись", few: "записи", many: "записей"),
                icon: "sum",
                tint: .orange
            )
            StatCard(
                title: "Средний расход",
                value: filtered.isEmpty ? "—" : Fmt.moneyRounded(Stats.average(filtered.map(\.amount))),
                subtitle: "по всем категориям",
                icon: "chart.bar.fill",
                tint: .red
            )
            StatCard(
                title: "Обязательные",
                value: Fmt.money(mandatoryTotal),
                subtitle: total > 0 ? "\(Fmt.percent(mandatoryTotal / total)) от расходов" : "жильё, гараж, КУ, связь",
                icon: "calendar.badge.clock",
                tint: .blue
            )
            StatCard(
                title: "Подписки",
                value: Fmt.money(subscriptionTotal),
                subtitle: total > 0 ? "\(Fmt.percent(subscriptionTotal / total)) от расходов" : "сервисы и приложения",
                icon: "repeat.circle.fill",
                tint: .purple
            )
        }
        .padding(16)
    }

    private var table: some View {
        Table(filtered, selection: $selection) {
            TableColumn("Дата") { entry in
                Text(MonthFormat.day(entry.date))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 115)

            TableColumn("Категория") { entry in
                TagBadge(text: entry.category.title, color: entry.category.color, icon: entry.category.icon)
            }
            .width(min: 130, ideal: 170)

            TableColumn("Сумма") { entry in
                Text(Fmt.money(entry.amount))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .width(min: 110, ideal: 135)

            TableColumn("Комментарий") { entry in
                Text(entry.note)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: PersistentIdentifier.self) { identifiers in
            if let entry = entry(for: identifiers) {
                Button("Изменить") { editor = EditorContext(entry: entry) }
                Divider()
                Button("Удалить", role: .destructive) { delete(identifiers) }
            }
        } primaryAction: { identifiers in
            if let entry = entry(for: identifiers) {
                editor = EditorContext(entry: entry)
            }
        }
        .overlay {
            if filtered.isEmpty {
                ContentUnavailableView {
                    Label(
                        expenses.isEmpty ? "Пока нет расходов" : "Ничего не найдено",
                        systemImage: "cart"
                    )
                } description: {
                    Text(
                        expenses.isEmpty
                            ? "Добавьте траты вручную или запишите платёж из раздела «Обязательные»."
                            : "Измените фильтры или поисковый запрос."
                    )
                } actions: {
                    if expenses.isEmpty {
                        Button("Добавить расход") {
                            editor = EditorContext(entry: nil)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private var yearPicker: some View {
        Picker("Год", selection: $selectedYear) {
            Text("Все годы").tag(Int?.none)
            ForEach(availableYears, id: \.self) { year in
                Text(String(year)).tag(Int?.some(year))
            }
        }
        .pickerStyle(.menu)
        .frame(width: 105)
        .help("Фильтр по году")
    }

    private var categoryFilter: some View {
        Menu {
            Button("Все категории") {
                selectedCategories.removeAll()
            }
            Divider()
            ForEach(ExpenseCategory.allCases) { category in
                Toggle(isOn: Binding(
                    get: { selectedCategories.contains(category) },
                    set: { isOn in
                        if isOn {
                            selectedCategories.insert(category)
                        } else {
                            selectedCategories.remove(category)
                        }
                    }
                )) {
                    Label(category.title, systemImage: category.icon)
                }
            }
        } label: {
            Label(
                selectedCategories.isEmpty ? "Все категории" : "Категории: \(selectedCategories.count)",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .help("Фильтр по категориям")
    }

    private var addButton: some View {
        Button {
            editor = EditorContext(entry: nil)
        } label: {
            Label("Добавить", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: .command)
        .help("Добавить расход (⌘N)")
    }

    private var editButton: some View {
        Button {
            if let entry = entry(for: selection) {
                editor = EditorContext(entry: entry)
            }
        } label: {
            Label("Изменить", systemImage: "pencil")
        }
        .keyboardShortcut("e", modifiers: .command)
        .disabled(selection.count != 1)
        .help("Изменить выбранный расход (⌘E)")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            delete(selection)
        } label: {
            Label("Удалить", systemImage: "trash")
        }
        .disabled(selection.isEmpty)
        .help("Удалить выбранные расходы")
    }

    private func entry(for identifiers: Set<PersistentIdentifier>) -> ExpenseEntry? {
        guard identifiers.count == 1, let identifier = identifiers.first else { return nil }
        return expenses.first { $0.persistentModelID == identifier }
    }

    private func delete(_ identifiers: Set<PersistentIdentifier>) {
        for identifier in identifiers {
            if let entry = expenses.first(where: { $0.persistentModelID == identifier }) {
                context.delete(entry)
            }
        }
        selection.removeAll()
        try? context.save()
    }
}
