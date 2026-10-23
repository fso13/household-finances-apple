import AppKit
import FinancesCore
import FinancesUI
import SwiftData
import SwiftUI

@main
struct FinancesApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var bootstrap = AppBootstrap()

    var body: some Scene {
        Window("Финансы", id: "main") {
            Group {
                if let container = bootstrap.container {
                    RootView(container: container)
                        .environmentObject(appState)
                        .modelContainer(container)
                } else {
                    RecoveryView(
                        error: bootstrap.error,
                        onRetry: { bootstrap.load() },
                        onOpenFolder: { bootstrap.openDataFolder() },
                        onReset: { bootstrap.resetStore() }
                    )
                }
            }
            .frame(minWidth: 1040, minHeight: 700)
            .tint(.indigo)
        }
        .defaultSize(width: 1340, height: 880)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {
                Button("Отменить") {
                    bootstrap.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!bootstrap.canUndo)

                Button("Повторить") {
                    bootstrap.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!bootstrap.canRedo)
            }
        }

        MenuBarExtra("Финансы", systemImage: "chart.pie.fill") {
            MenuBarContent()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarContent: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Открыть финансы") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Добавить доход") {
            appState.requestQuickAdd(.income)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Button("Добавить расход") {
            appState.requestQuickAdd(.expense)
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }

        Divider()

        Button("Выйти") {
            NSApp.terminate(nil)
        }
    }
}
