import SwiftData
import SwiftUI
import FinancesCore

package struct RootView: View {
    package let container: ModelContainer
    package init(container: ModelContainer) {
        self.container = container
    }

    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showWelcome = false
    @ObservedObject private var errorCenter = ErrorCenter.shared

    package var body: some View {
        NavigationSplitView {
            SidebarView(route: $appState.route)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showWelcome, onDismiss: { hasOnboarded = true }) {
            WelcomeView { loadDemo in
                if loadDemo {
                    do {
                        try DemoData.seed(context: context)
                    } catch {
                        ErrorCenter.shared.report(error)
                    }
                }
                hasOnboarded = true
                showWelcome = false
            }
        }
        .task {
            bootstrap()
        }
        .alert(
            "Что-то пошло не так",
            isPresented: Binding(
                get: { errorCenter.error != nil },
                set: { newValue in if !newValue { errorCenter.dismiss() } }
            ),
            presenting: errorCenter.error
        ) { _ in
            Button("Понятно", role: .cancel) {
                errorCenter.dismiss()
            }
        } message: { error in
            Text(
                [error.errorDescription, error.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
    }

    private func bootstrap() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments

        if SnapshotRunner.isEnabled {
            try? DemoData.seed(context: context)
            hasOnboarded = true
            showWelcome = false
            SnapshotRunner.run(state: appState, context: context, container: container)
            return
        }

        if arguments.contains("--demo") {
            try? DemoData.seed(context: context)
            hasOnboarded = true
            showWelcome = false
        } else if !hasOnboarded {
            showWelcome = true
        }

        if let routeArgument = arguments.first(where: { $0.hasPrefix("--route=") }) {
            let rawRoute = routeArgument.replacingOccurrences(of: "--route=", with: "")
            if let parsedRoute = AppRoute(rawValue: rawRoute) {
                appState.route = parsedRoute
            }
        }
        #else
        if !hasOnboarded {
            showWelcome = true
        }
        #endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.route ?? .dashboard {
        case .dashboard:
            DashboardView()
        case .income:
            IncomeView()
        case .expenses:
            ExpensesView()
        case .budgets:
            BudgetsView()
        case .recurring:
            RecurringView()
        case .subscriptions:
            SubscriptionsView()
        case .analytics:
            AnalyticsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Боковая панель

struct SidebarView: View {
    @Binding var route: AppRoute?

    var body: some View {
        List(selection: $route) {
            Section {
                row(.dashboard)
            }

            Section("Данные") {
                row(.income)
                row(.expenses)
                row(.budgets)
                row(.recurring)
                row(.subscriptions)
            }

            Section("Анализ") {
                row(.analytics)
            }

            Section {
                row(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 280)
        .safeAreaInset(edge: .top, spacing: 0) {
            brand
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.indigo, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "rublesign")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Финансы")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("личный бюджет")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func row(_ item: AppRoute) -> some View {
        Label {
            Text(item.title)
                .font(.system(size: 13, weight: .medium))
        } icon: {
            Image(systemName: item.icon)
                .foregroundStyle(item.color)
        }
        .tag(item)
    }
}
