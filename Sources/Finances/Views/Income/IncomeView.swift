import SwiftData
import SwiftUI

struct IncomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \IncomeEntry.date, order: .reverse) private var incomes: [IncomeEntry]

    @State private var selectedTypes: Set<IncomeType> = []
    @State private var selectedYear: Int? = nil
    @State private var search = ""
    @State private var selection = Set<PersistentIdentifier>()
    @State private var editor: EditorContext?

    private struct EditorContext: Identifiable {
        let id = UUID()
        let entry: IncomeEntry?
    }

    // MARK: - Фильтры

    private var availableYears: [Int] {
        Array(Set(incomes.map { $0.date.year })).sorted(by: >)
    }

    private var filtered: [IncomeEntry] {
        incomes.filter { entry in
            let matchesYear = selectedYear == nil || entry.date.year == selectedYear
            let matchesType = selectedTypes.isEmpty || selectedTypes.contains(entry.type)
            let matchesSearch = search.isEmpty
                || entry.employer.localizedCaseInsensitiveContains(search)
                || entry.note.localizedCaseInsensitiveContains(search)
                || entry.type.title.localizedCaseInsensitiveContains(search)
            return matchesYear && matchesType && matchesSearch
        }
    }

    private var total: Double {
        Stats.total(filtered.map(\.amount))
    }

    private var salaryEntries: [IncomeEntry] {
        filtered.filter { $0.type == .salary }
    }

    // MARK: - Вид

    var body: some View {
        VStack(spacing: 0) {
            summary
            Divider()
            table
        }
        .navigationTitle("Доходы")
        .searchable(text: $search, prompt: "Поиск по доходам")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                yearPicker
                typeFilter
                editButton
                deleteButton
                addButton
            }
        }
        .sheet(item: $editor) { editorContext in
            IncomeEditorSheet(existing: editorContext.entry)
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Всего",
                value: Fmt.money(total),
                subtitle: Fmt.plural(filtered.count, one: "выплата", few: "выплаты", many: "выплат"),
                icon: "sum",
                tint: .green
            )
            StatCard(
                title: "Средняя выплата",
                value: filtered.isEmpty ? "—" : Fmt.moneyRounded(Stats.average(filtered.map(\.amount))),
                subtitle: "по всем типам",
                icon: "chart.bar.fill",
                tint: .blue
            )
            StatCard(
                title: "Медиана",
                value: filtered.isEmpty ? "—" : Fmt.moneyRounded(Stats.median(filtered.map(\.amount))),
                subtitle: "устойчивое среднее",
                icon: "chart.bar.doc.horizontal.fill",
                tint: .indigo
            )
            StatCard(
                title: "Средняя зарплата",
                value: salaryEntries.isEmpty ? "—" : Fmt.moneyRounded(Stats.average(salaryEntries.map(\.amount))),
                subtitle: salaryEntries.isEmpty
                    ? "нет выплат типа «Зарплата»"
                    : Fmt.plural(salaryEntries.count, one: "выплата", few: "выплаты", many: "выплат"),
                icon: "briefcase.fill",
                tint: .teal
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

            TableColumn("Тип") { entry in
                TagBadge(text: entry.type.title, color: entry.type.color, icon: entry.type.icon)
            }
            .width(min: 120, ideal: 145)

            TableColumn("Сумма") { entry in
                Text(Fmt.money(entry.amount))
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .width(min: 110, ideal: 130)

            TableColumn("Работодатель") { entry in
                Text(entry.employer)
                    .lineLimit(1)
            }

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
                        incomes.isEmpty ? "Пока нет выплат" : "Ничего не найдено",
                        systemImage: "banknote"
                    )
                } description: {
                    Text(
                        incomes.isEmpty
                            ? "Добавьте зарплату, аванс, премию или другую выплату."
                            : "Измените фильтры или поисковый запрос."
                    )
                } actions: {
                    if incomes.isEmpty {
                        Button("Добавить выплату") {
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

    private var typeFilter: some View {
        Menu {
            Button("Все типы") {
                selectedTypes.removeAll()
            }
            Divider()
            ForEach(IncomeType.allCases) { type in
                Toggle(isOn: Binding(
                    get: { selectedTypes.contains(type) },
                    set: { isOn in
                        if isOn {
                            selectedTypes.insert(type)
                        } else {
                            selectedTypes.remove(type)
                        }
                    }
                )) {
                    Label(type.title, systemImage: type.icon)
                }
            }
        } label: {
            Label(
                selectedTypes.isEmpty ? "Все типы" : "Типы: \(selectedTypes.count)",
                systemImage: "line.3.horizontal.decrease.circle"
            )
        }
        .help("Фильтр по типам выплат")
    }

    private var addButton: some View {
        Button {
            editor = EditorContext(entry: nil)
        } label: {
            Label("Добавить", systemImage: "plus")
        }
        .keyboardShortcut("n", modifiers: .command)
        .help("Добавить выплату (⌘N)")
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
        .help("Изменить выбранную выплату (⌘E)")
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            delete(selection)
        } label: {
            Label("Удалить", systemImage: "trash")
        }
        .disabled(selection.isEmpty)
        .help("Удалить выбранные выплаты")
    }

    private func entry(for identifiers: Set<PersistentIdentifier>) -> IncomeEntry? {
        guard identifiers.count == 1, let identifier = identifiers.first else { return nil }
        return incomes.first { $0.persistentModelID == identifier }
    }

    private func delete(_ identifiers: Set<PersistentIdentifier>) {
        for identifier in identifiers {
            if let entry = incomes.first(where: { $0.persistentModelID == identifier }) {
                context.delete(entry)
            }
        }
        selection.removeAll()
        try? context.save()
    }
}
