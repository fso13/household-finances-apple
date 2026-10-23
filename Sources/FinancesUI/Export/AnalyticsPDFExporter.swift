import AppKit
import CoreGraphics
import PDFKit
import FinancesCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Данные отчёта

struct AnalyticsReportData {
    let period: String
    let income: Double
    let expense: Double
    let net: Double
    let savingsRate: Double
    let topExpenses: [CategorySlice]
    let monthly: [MonthBucket]
    let changes: [CategoryChange]
    let generatedAt: Date
}

// MARK: - PDF

@MainActor
enum AnalyticsPDFExporter {
    static func export(_ data: AnalyticsReportData) {
        guard let pdf = pdfData(data) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName(for: data)
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? pdf.write(to: url)
    }

    static func printReport(_ data: AnalyticsReportData) {
        guard let pdf = pdfData(data), let document = PDFDocument(data: pdf) else { return }
        let view = PDFView(frame: NSRect(x: 0, y: 0, width: 900, height: 1200))
        view.document = document
        view.print(with: NSPrintInfo.shared, autoRotate: true)
    }

    static func pdfData(_ data: AnalyticsReportData) -> Data? {
        let renderer = ImageRenderer(
            content: AnalyticsReportView(data: data)
                .frame(width: 1000)
                .background(Color.white)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2

        let output = NSMutableData()
        renderer.render { size, renderInContext in
            var mediaBox = CGRect(x: 0, y: 0, width: 1000, height: 1400)
            guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return }
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            let pageBox = CGRect(origin: .zero, size: size)
            let pageInfo = [kCGPDFContextMediaBox as String: pageBox] as CFDictionary
            context.beginPDFPage(pageInfo)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
        }
        return output.length > 0 ? output as Data : nil
    }

    private static func suggestedName(for data: AnalyticsReportData) -> String {
        let sanitized =
            data.period
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "—", with: "-")
        return "Финансы — \(sanitized).pdf"
    }
}

// MARK: - Печатный макет

private struct AnalyticsReportView: View {
    let data: AnalyticsReportData

    private let ink = Color(red: 0.08, green: 0.09, blue: 0.12)
    private let muted = Color(red: 0.38, green: 0.40, blue: 0.45)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            header
            kpis
            expensesSection

            if !data.monthly.isEmpty {
                monthsSection
            }
            if !data.changes.isEmpty {
                changesSection
            }

            Divider()
            Text("Сформировано локально в приложении «Финансы» · \(MonthFormat.day(data.generatedAt))")
                .font(.system(size: 10))
                .foregroundStyle(muted)
        }
        .padding(40)
        .foregroundStyle(ink)
        .background(Color.white)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ФИНАНСЫ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Color(red: 0.35, green: 0.28, blue: 0.86))
                Text("Аналитика")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(data.period)
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
            }
            Spacer()
            Text("Личный бюджет")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(muted)
        }
    }

    private var kpis: some View {
        HStack(spacing: 12) {
            kpi("Доходы", Fmt.moneyRounded(data.income), Color(red: 0.13, green: 0.55, blue: 0.28))
            kpi("Расходы", Fmt.moneyRounded(data.expense), Color(red: 0.88, green: 0.43, blue: 0.12))
            kpi(
                "Чистый поток",
                Fmt.moneyRounded(data.net),
                data.net >= 0 ? Color(red: 0.10, green: 0.50, blue: 0.52) : Color(red: 0.78, green: 0.18, blue: 0.18)
            )
            kpi("Норма сбережений", Fmt.percent(data.savingsRate), Color(red: 0.35, green: 0.28, blue: 0.86))
        }
    }

    private func kpi(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(muted)
            Text(value)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(red: 0.96, green: 0.96, blue: 0.98), in: RoundedRectangle(cornerRadius: 8))
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Расходы по категориям")
                .font(.system(size: 15, weight: .semibold))
            if data.topExpenses.isEmpty {
                Text("Нет расходов за период.")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
            } else {
                let maxValue = data.topExpenses.map(\.value).max() ?? 1
                ForEach(data.topExpenses) { slice in
                    HStack(spacing: 10) {
                        Text(slice.title)
                            .font(.system(size: 11))
                            .frame(width: 150, alignment: .leading)
                        GeometryReader { proxy in
                            Capsule()
                                .fill(slice.color.opacity(0.18))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(slice.color)
                                        .frame(width: proxy.size.width * (slice.value / maxValue))
                                }
                        }
                        .frame(height: 7)
                        Text(Fmt.moneyRounded(slice.value))
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .frame(width: 100, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var monthsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Динамика по месяцам")
                .font(.system(size: 15, weight: .semibold))
            monthRow("Месяц", "Доходы", "Расходы", "Остаток", isHeader: true)
            ForEach(data.monthly) { bucket in
                monthRow(
                    MonthFormat.monthTitle(bucket.month),
                    Fmt.moneyRounded(bucket.income),
                    Fmt.moneyRounded(bucket.expense),
                    Fmt.moneyRounded(bucket.net),
                    isHeader: false
                )
            }
        }
    }

    private func monthRow(
        _ month: String,
        _ income: String,
        _ expense: String,
        _ net: String,
        isHeader: Bool
    ) -> some View {
        HStack {
            Text(month).frame(width: 220, alignment: .leading)
            Text(income).frame(maxWidth: .infinity, alignment: .trailing)
            Text(expense).frame(maxWidth: .infinity, alignment: .trailing)
            Text(net).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 10, weight: isHeader ? .semibold : .regular))
        .foregroundStyle(isHeader ? muted : ink)
        .monospacedDigit()
        .padding(.vertical, 3)
    }

    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Изменения к прошлому периоду")
                .font(.system(size: 15, weight: .semibold))
            ForEach(data.changes) { change in
                HStack {
                    Text(change.category.title)
                        .font(.system(size: 11))
                    Spacer()
                    Text("\(Fmt.moneyRounded(change.previous)) → \(Fmt.moneyRounded(change.current))")
                        .font(.system(size: 10))
                        .foregroundStyle(muted)
                        .monospacedDigit()
                    Text(Fmt.signedMoney(change.delta))
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(
                            change.isGrowth
                                ? Color(red: 0.78, green: 0.18, blue: 0.18)
                                : Color(red: 0.13, green: 0.55, blue: 0.28)
                        )
                        .frame(width: 110, alignment: .trailing)
                }
            }
        }
    }
}
