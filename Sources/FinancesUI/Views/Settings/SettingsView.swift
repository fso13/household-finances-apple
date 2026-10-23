import SwiftData
import SwiftUI
import FinancesCore

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query private var incomes: [IncomeEntry]
    @Query private var expenses: [ExpenseEntry]
    @Query private var recurring: [RecurringPayment]
    @Query private var subscriptions: [Subscription]

    @AppStorage("budgetNotificationsEnabled") private var budgetNotificationsEnabled = true
    @AppStorage("paymentRemindersEnabled") private var paymentRemindersEnabled = true
    @AppStorage("dashboard.showForecast") private var dashboardForecast = true
    @AppStorage("dashboard.showCharts") private var dashboardCharts = true
    @AppStorage("dashboard.showFixed") private var dashboardFixed = true
    @AppStorage("dashboard.showSubscriptions") private var dashboardSubscriptions = true
    @AppStorage("dashboard.showBudgets") private var dashboardBudgets = true
    @State private var confirmLoadDemo = false
    @State private var confirmClear = false
    @State private var activeSheet: SettingsSheet?
    @State private var resultMessage: String?
    @State private var showCategories = false
    @State private var customCategoryCount = CustomCategoryCatalog.shared.categories.count
    @State private var showCategoryRules = false
    @State private var categoryRuleCount = CategoryRuleCatalog.shared.rules.count

    private enum SettingsSheet: Identifiable {
        case backup(BackupEnvelope)
        case csv(CSVImportPreview)

        var id: String {
            switch self {
            case .backup(let envelope): "backup-\(envelope.createdAt.timeIntervalSince1970)"
            case .csv(let preview): "csv-\(preview.id.uuidString)"
            }
        }
    }

    private var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var appVersion: String {
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(marketingVersion) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dataCard
                categoriesCard
                categoryRulesCard
                dashboardCard
                notificationsCard
                backupCard
                exportCard
                aboutCard
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Настройки")
        .alert("Загрузить демо-данные?", isPresented: $confirmLoadDemo) {
            Button("Загрузить", role: .destructive) {
                do {
                    try BackupStore.createAutomaticBackup(
                        context: context,
                        reason: "before-demo",
                        appVersion: marketingVersion
                    )
                    try DemoData.seed(context: context, replace: true)
                } catch {
                    ErrorCenter.shared.report(error)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text(
                "Текущие доходы, расходы, платежи и подписки будут заменены демонстрационным набором за последние 24 месяца."
            )
        }
        .alert("Удалить все данные?", isPresented: $confirmClear) {
            Button("Удалить всё", role: .destructive) {
                do {
                    try DemoData.clear(context: context)
                } catch {
                    ErrorCenter.shared.report(error)
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут удалены все доходы, расходы, обязательные платежи и подписки. Действие нельзя отменить.")
        }
    }

    private var dataCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Данные",
                    subtitle: "хранятся локально на этом Mac",
                    icon: "externaldrive.fill",
                    tint: .blue
                )

                HStack(spacing: 12) {
                    countTile("Доходы", incomes.count, .green)
                    countTile("Расходы", expenses.count, .orange)
                    countTile("Платежи", recurring.count, .blue)
                    countTile("Подписки", subscriptions.count, .purple)
                }

                Divider()

                settingsRow(
                    icon: "sparkles",
                    tint: .indigo,
                    title: "Демо-данные",
                    subtitle: "24 месяца выплат, платежей и подписок",
                    actionTitle: "Загрузить"
                ) {
                    confirmLoadDemo = true
                }

                Divider()

                settingsRow(
                    icon: "trash",
                    tint: .red,
                    title: "Очистить всё",
                    subtitle: "удалить доходы, расходы, шаблоны и подписки",
                    actionTitle: "Очистить",
                    destructive: true
                ) {
                    confirmClear = true
                }
            }
        }
    }

    private var categoriesCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Категории",
                    subtitle: "встроенные и пользовательские",
                    icon: "tag.fill",
                    tint: .pink
                )

                HStack(spacing: 12) {
                    IconTile(symbol: "tag.fill", tint: .pink, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Пользовательские категории")
                            .font(.callout.weight(.medium))
                        Text("\(customCategoryCount) добавлено · появятся в расходах и бюджетах")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Управлять") {
                        showCategories = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .sheet(
            isPresented: $showCategories,
            onDismiss: {
                customCategoryCount = CustomCategoryCatalog.shared.categories.count
            }
        ) {
            CategoriesSettingsView()
        }
    }

    private var categoryRulesCard: some View {
        CardView {
            HStack(spacing: 12) {
                IconTile(symbol: "wand.and.stars", tint: .purple, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Правила категоризации")
                        .font(.callout.weight(.medium))
                    Text("\(categoryRuleCount) правил · ключевые слова в заметках")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Управлять") { showCategoryRules = true }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .sheet(
            isPresented: $showCategoryRules,
            onDismiss: {
                categoryRuleCount = CategoryRuleCatalog.shared.rules.count
            }
        ) {
            CategoryRulesSettingsView()
        }
    }

    private var dashboardCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(
                    title: "Дашборд",
                    subtitle: "какие карточки показывать на обзоре",
                    icon: "rectangle.3.group.fill",
                    tint: .indigo
                )

                Toggle("Прогноз до конца месяца", isOn: $dashboardForecast)
                Toggle("Графики доходов и расходов", isOn: $dashboardCharts)
                Toggle("Обязательные платежи", isOn: $dashboardFixed)
                Toggle("Подписки", isOn: $dashboardSubscriptions)
                Toggle("Бюджеты", isOn: $dashboardBudgets)

                Text("KPI-строка с доходами, расходами и остатком остаётся всегда.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var notificationsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Уведомления",
                    subtitle: "локальные, без сети",
                    icon: "bell.fill",
                    tint: .orange
                )

                Toggle("Предупреждать о превышении бюджета", isOn: $budgetNotificationsEnabled)
                    .onChange(of: budgetNotificationsEnabled) { _, enabled in
                        if enabled {
                            BudgetNotificationService.requestAuthorization()
                        }
                    }

                Toggle("Напоминать о платежах за 7 дней", isOn: $paymentRemindersEnabled)
                    .onChange(of: paymentRemindersEnabled) { _, enabled in
                        if enabled {
                            PaymentReminderService.requestAuthorization()
                        }
                    }

                Text(
                    "Бюджетное уведомление приходит один раз для каждой категории и месяца. Напоминания о платежах ставятся на 9:00 за 7 дней до списания."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var backupCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Резервные копии",
                    subtitle: "JSON со всеми данными и версией схемы",
                    icon: "shippingbox.fill",
                    tint: .orange
                )

                settingsRow(
                    icon: "square.and.arrow.up",
                    tint: .orange,
                    title: "Экспортировать бэкап",
                    subtitle: "доходы, расходы, платежи и подписки",
                    actionTitle: "Экспорт"
                ) {
                    do {
                        try BackupExporter.export(context: context, appVersion: marketingVersion)
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }

                Divider()

                settingsRow(
                    icon: "square.and.arrow.down",
                    tint: .blue,
                    title: "Импортировать бэкап",
                    subtitle: "с предпросмотром и выбором режима",
                    actionTitle: "Импорт"
                ) {
                    do {
                        if let envelope = try BackupExporter.chooseBackup() {
                            activeSheet = .backup(envelope)
                        }
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }

                Divider()

                settingsRow(
                    icon: "folder",
                    tint: .secondary,
                    title: "Папка автобэкапов",
                    subtitle: "последние копии перед очисткой и импортом",
                    actionTitle: "Открыть"
                ) {
                    BackupExporter.openBackupsFolder()
                }

                Text(
                    "Автобэкапы создаются перед очисткой, заменой демо-данных и восстановлением. Хранятся последние 10 копий."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var exportCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Экспорт",
                    subtitle: "резервная копия в CSV для Excel и Numbers",
                    icon: "square.and.arrow.up.fill",
                    tint: .teal
                )

                settingsRow(
                    icon: "tablecells",
                    tint: .teal,
                    title: "Экспортировать в CSV",
                    subtitle: "все операции, регулярные платежи и подписки",
                    actionTitle: "Экспорт"
                ) {
                    do {
                        try Exporter.exportCSV(context: context)
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }

                Divider()

                settingsRow(
                    icon: "tablecells.badge.ellipsis",
                    tint: .blue,
                    title: "Импортировать операции из CSV",
                    subtitle: "дата, раздел, тип, категория, сумма, комментарий",
                    actionTitle: "Импорт"
                ) {
                    do {
                        if let preview = try Exporter.chooseCSV() {
                            activeSheet = .csv(preview)
                        }
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }

                Text(
                    "CSV: UTF-8, разделитель «;» или «,», даты ISO/ДД.ММ.ГГГГ, суммы с точкой или запятой. Перед импортом создаётся бэкап."
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private var aboutCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Финансы")
                            .font(.title3.weight(.bold))
                        Text("Версия \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Divider()

                Text(
                    "Личный трекер выплат и обязательных расходов: типы доходов, средние значения, округления платежей за квартиру, гараж и коммуналку, подписки и наглядная аналитика по месяцам, кварталам и годам."
                )
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Label("SwiftUI", systemImage: "swift")
                    Label("SwiftData", systemImage: "internaldrive")
                    Label("Swift Charts", systemImage: "chart.bar.xaxis")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }

    private func countTile(_ title: String, _ count: Int, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func settingsRow(
        icon: String,
        tint: Color,
        title: String,
        subtitle: String,
        actionTitle: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: icon, tint: tint, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if destructive {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.small)
            } else {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }
}
