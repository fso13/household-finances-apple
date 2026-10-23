import SwiftData
import SwiftUI

struct RootView: View {
    let container: ModelContainer
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var appState: AppState
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @State private var showWelcome = false

    var body: some View {
        NavigationSplitView {
            SidebarView(route: $appState.route)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showWelcome, onDismiss: { hasOnboarded = true }) {
            WelcomeView { loadDemo in
                if loadDemo {
                    DemoData.seed(context: context)
                }
                hasOnboarded = true
                showWelcome = false
            }
        }
        .task {
            bootstrap()
        }
    }

    /// Служебные аргументы запуска: `--demo` и `--route=analytics`.
    private func bootstrap() {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--demo") || SnapshotRunner.isEnabled {
            DemoData.seed(context: context)
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

        SnapshotRunner.run(state: appState, context: context, container: container)
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
