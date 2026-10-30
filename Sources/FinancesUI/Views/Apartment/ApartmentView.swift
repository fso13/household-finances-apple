import AppKit
import FinancesCore
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ApartmentView: View {
    @Environment(\.modelContext) private var context

    @Query private var months: [ApartmentMonth]

    @State private var year: Int = Date().year
    @State private var resultMessage: String?
    @State private var isWorking = false

    private var yearMonths: [ApartmentMonth] {
        months.filter { $0.year == year }.sorted { $0.month < $1.month }
    }

    private var totalDue: Double {
        yearMonths.reduce(0) { $0 + $1.total }
    }
    private var totalPaid: Double {
        yearMonths.reduce(0) { $0 + $1.paid }
    }
    private var totalOverpayment: Double {
        yearMonths.reduce(0) { $0 + $1.overpayment }
    }
    private var filledMonths: Int {
        yearMonths.filter {
            $0.rentKopecks != 0 || $0.capitalRepairKopecks != 0
                || $0.utilitiesKopecks != 0 || $0.electricityKopecks != 0
                || $0.paidKopecks != 0
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summary
                table
                Text("Итого считается как аренда + капремонт + коммуналка + свет. Переплата — заплатил минус итого.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .navigationTitle("Квартира")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Импортировать XLSX…") { importFile() }
                    Button("Экспортировать XLSX…") { exportFile() }
                } label: {
                    Label("Файл", systemImage: "square.and.arrow.up.on.square")
                }
                .disabled(isWorking)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    ensureMonths()
                } label: {
                    Label("Заполнить месяцы", systemImage: "calendar.badge.plus")
                }
                .help("Создать пустые строки на год")
            }
        }
        .task { ensureMonths() }
        .onChange(of: year) { _, _ in ensureMonths() }
        .alert(
            "Готово",
            isPresented: Binding(
                get: { resultMessage != nil },
                set: { if !$0 { resultMessage = nil } }
            )
        ) {
            Button("Понятно", role: .cancel) { resultMessage = nil }
        } message: {
            Text(resultMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Платежи за квартиру")
                    .font(.title2.weight(.bold))
                Text("аренда, капремонт, коммуналка и свет")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Button {
                    year -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                Text(String(year))
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .frame(width: 56)
                Button {
                    year += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Итого за год",
                value: Fmt.moneyRounded(totalDue),
                subtitle: "\(filledMonths) мес. с данными",
                icon: "building.2.fill",
                tint: .blue
            )
            StatCard(
                title: "Заплачено",
                value: Fmt.moneyRounded(totalPaid),
                subtitle: "за \(year) год",
                icon: "banknote.fill",
                tint: .green
            )
            StatCard(
                title: "Переплата",
                value: Fmt.moneyRounded(totalOverpayment),
                subtitle: totalOverpayment < 0 ? "недоплата" : "запас",
                icon: "arrow.left.arrow.right",
                tint: totalOverpayment < 0 ? .red : .teal,
                valueColor: totalOverpayment < 0 ? .red : .primary
            )
        }
    }

    private var table: some View {
        CardView(padding: 12) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text("Месяц").frame(width: 92, alignment: .leading)
                    Text("Аренда").frame(width: 92, alignment: .trailing)
                    Text("Капремонт").frame(width: 92, alignment: .trailing)
                    Text("Коммуналка").frame(width: 92, alignment: .trailing)
                    Text("Свет").frame(width: 82, alignment: .trailing)
                    Text("Итого").frame(width: 96, alignment: .trailing)
                    Text("Заплатил").frame(width: 96, alignment: .trailing)
                    Text("Переплата").frame(width: 96, alignment: .trailing)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 8)
                Divider()

                ForEach(1...12, id: \.self) { number in
                    if let month = yearMonths.first(where: { $0.month == number }) {
                        ApartmentRow(month: month)
                    }
                    if number != 12 {
                        Divider().padding(.leading, 6)
                    }
                }
            }
        }
    }

    private func ensureMonths() {
        let existing = Set(yearMonths.map(\.month))
        var inserted = false
        for number in 1...12 where !existing.contains(number) {
            context.insert(ApartmentMonth(year: year, month: number))
            inserted = true
        }
        if inserted {
            try? Persistence.save(context, operation: "apartment.ensureMonths")
        }
    }

    private func importFile() {
        let panel = NSOpenPanel()
        panel.title = "Импорт платежей за квартиру"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let data = try ApartmentXLSXCodec.importFile(from: url)
            guard !data.isEmpty else {
                resultMessage = "В файле не найдено месяцев с данными."
                return
            }
            for item in data {
                if let month = months.first(where: { $0.year == item.year && $0.month == item.month }) {
                    month.rent = item.rent
                    month.capitalRepair = item.capitalRepair
                    month.utilities = item.utilities
                    month.electricity = item.electricity
                    month.paid = item.paid
                } else {
                    context.insert(
                        ApartmentMonth(
                            year: item.year,
                            month: item.month,
                            rent: item.rent,
                            capitalRepair: item.capitalRepair,
                            utilities: item.utilities,
                            electricity: item.electricity,
                            paid: item.paid
                        )
                    )
                }
            }
            try Persistence.save(context, operation: "apartment.import")
            year = data.map(\.year).max() ?? year
            resultMessage = "Импортировано месяцев: \(data.count)."
        } catch {
            ErrorCenter.shared.report(error)
        }
    }

    private func exportFile() {
        let panel = NSSavePanel()
        panel.title = "Экспорт платежей за квартиру"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
        panel.nameFieldStringValue = "Квартира-\(year).xlsx"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        isWorking = true
        defer { isWorking = false }
        do {
            let data =
                months
                .sorted { ($0.year, $0.month) < ($1.year, $1.month) }
                .map(ApartmentMonthData.init)
            guard !data.isEmpty else {
                resultMessage = "Нет данных для экспорта."
                return
            }
            try ApartmentXLSXCodec.export(months: data, to: url)
            resultMessage = "Экспортировано месяцев: \(data.count)."
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}

private struct ApartmentRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var month: ApartmentMonth

    var body: some View {
        HStack(spacing: 6) {
            Text(MonthFormat.shortMonth(month.monthStart))
                .font(.caption.weight(.medium))
                .frame(width: 92, alignment: .leading)

            moneyField($month.rent)
            moneyField($month.capitalRepair)
            moneyField($month.utilities)
            moneyField($month.electricity)

            Text(Fmt.money(month.total))
                .font(.caption.monospacedDigit())
                .frame(width: 96, alignment: .trailing)

            moneyField($month.paid)

            Text(Fmt.signedMoney(month.overpayment))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(month.overpayment < 0 ? Color.red : Color.green)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .onChange(of: month.rentKopecks) { _, _ in save() }
        .onChange(of: month.capitalRepairKopecks) { _, _ in save() }
        .onChange(of: month.utilitiesKopecks) { _, _ in save() }
        .onChange(of: month.electricityKopecks) { _, _ in save() }
        .onChange(of: month.paidKopecks) { _, _ in save() }
    }

    private func moneyField(_ value: Binding<Double>) -> some View {
        TextField(
            "",
            value: value,
            format: .number.precision(.fractionLength(0...2))
        )
        .textFieldStyle(.roundedBorder)
        .multilineTextAlignment(.trailing)
        .font(.caption.monospacedDigit())
        .frame(width: 92)
    }

    private func save() {
        do {
            try Persistence.save(context, operation: "apartment.save")
        } catch {
            ErrorCenter.shared.report(error)
        }
    }
}
