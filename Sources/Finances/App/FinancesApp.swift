import SwiftData
import SwiftUI

@main
struct FinancesApp: App {
    private let container: ModelContainer
    @StateObject private var appState = AppState()

    init() {
        do {
            let folder = URL.applicationSupportDirectory
                .appendingPathComponent("Finances", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let storeURL = folder.appendingPathComponent("Finances.store")
            let configuration = ModelConfiguration("Finances", url: storeURL)

            container = try ModelContainer(
                for: IncomeEntry.self,
                ExpenseEntry.self,
                RecurringPayment.self,
                Subscription.self,
                configurations: configuration
            )
        } catch {
            fatalError("Не удалось открыть локальное хранилище: \(error)")
        }
        container.mainContext.autosaveEnabled = true
    }

    var body: some Scene {
        Window("Финансы", id: "main") {
            RootView(container: container)
                .frame(minWidth: 1040, minHeight: 700)
                .tint(.indigo)
                .environmentObject(appState)
        }
        .modelContainer(container)
        .defaultSize(width: 1340, height: 880)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
