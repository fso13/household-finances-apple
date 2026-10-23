import AppKit
import Charts
import SwiftUI
import FinancesCore

// MARK: - Карточка

struct CardView<Content: View>: View {
    var padding: CGFloat = 18
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
            }
    }
}

// MARK: - KPI-карточка

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var icon: String = "chart.bar.fill"
    var tint: Color = .accentColor
    var valueColor: Color = .primary
    var badge: String? = nil

    var body: some View {
        CardView(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22, height: 22)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(tint.opacity(0.12), in: Capsule())
                    }
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Бейджи и иконки

struct TagBadge: View {
    let text: String
    var color: Color = .secondary
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
    }
}

struct IconTile: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Заголовок секции

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 7) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.headline)
            }
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Пустые состояния

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

struct EmptyChartView: View {
    var text: String = "Нет данных за выбранный период"

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24))
                .foregroundStyle(.quaternary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Навигатор по месяцам

struct MonthNavigator: View {
    @Binding var month: Date
    var showsToday: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            Button {
                month = month.addingMonths(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Предыдущий месяц")
            .accessibilityLabel("Предыдущий месяц")

            Text(MonthFormat.monthTitle(month))
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 140)
                .multilineTextAlignment(.center)

            Button {
                month = month.addingMonths(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .help("Следующий месяц")
            .accessibilityLabel("Следующий месяц")

            if showsToday, !month.isSameMonth(as: .now) {
                Button("Сегодня") {
                    month = Date().startOfMonth
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.tint)
                .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }
}

// MARK: - Легенда

struct LegendList: View {
    let slices: [CategorySlice]
    var showPercent: Bool = true
    var compact: Bool = false
    var maxRows: Int = 7

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(slices.prefix(maxRows))) { slice in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(slice.color)
                        .frame(width: 8, height: 8)
                    Text(slice.title)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(compact ? Fmt.compact(slice.value) : Fmt.money(slice.value))
                        .font(.callout.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                    if showPercent, total > 0 {
                        Text(Fmt.percent(slice.value / total))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .frame(width: 42, alignment: .trailing)
                    }
                }
            }
        }
    }
}

// MARK: - Бублик

struct DonutChart: View {
    let slices: [CategorySlice]
    var centerTitle: String = "Всего"
    var height: CGFloat = 190
    var innerRadius: Double = 0.62

    private var total: Double {
        slices.reduce(0) { $0 + $1.value }
    }

    var body: some View {
        if slices.isEmpty {
            EmptyChartView()
                .frame(height: height)
        } else {
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Сумма", slice.value),
                    innerRadius: .ratio(innerRadius),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(slice.color)
            }
            .chartLegend(.hidden)
            .frame(height: height)
            .overlay {
                VStack(spacing: 2) {
                    Text(centerTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Fmt.compact(total))
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(centerTitle): \(Fmt.money(total))")
            .accessibilityValue(
                slices.prefix(4)
                    .map { "\($0.title) \(Fmt.money($0.value))" }
                    .joined(separator: ", ")
            )
        }
    }
}

// MARK: - Ось Y для графиков

@AxisContentBuilder
func compactYAxis() -> some AxisContent {
    AxisMarks(position: .leading) { value in
        AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(Color.primary.opacity(0.08))
        AxisValueLabel {
            if let amount = value.as(Double.self) {
                Text(Fmt.compact(amount))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Строка таблицы-сводки

struct SummaryRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    var bold: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(bold ? .callout.weight(.semibold) : .callout)
                .foregroundStyle(bold ? .primary : .secondary)
            Spacer(minLength: 12)
            Text(value)
                .font(bold ? .callout.weight(.bold) : .callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }
}
