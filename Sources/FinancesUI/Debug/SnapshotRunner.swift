#if DEBUG

import AppKit
import SwiftData
import SwiftUI
import FinancesCore

/// Служебный режим для проверки интерфейса без прав на запись экрана.
///
/// * `--snapshot` — снимает содержимое окна приложения для каждого раздела.
/// * `--offscreen` — рендерит разделы в высоком offscreen-окне, чтобы увидеть
///   весь скролл целиком (полезно для аналитики и длинных списков).
@MainActor
enum SnapshotRunner {
    static var isEnabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--snapshot") || arguments.contains("--offscreen")
    }

    static func run(state: AppState, context: ModelContext, container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("--offscreen") {
            runOffscreen(container: container)
            return
        }

        guard arguments.contains("--snapshot") else { return }

        let directory = snapshotDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))

            if arguments.contains("--dark") {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }

            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.contentView != nil }) {
                window.makeKeyAndOrderFront(nil)
                if arguments.contains("--tall") {
                    window.setContentSize(
                        NSSize(
                            width: max(window.contentView?.bounds.width ?? 0, 1_340),
                            height: 2_300
                        )
                    )
                    window.contentView?.layoutSubtreeIfNeeded()
                }
            }

            try? await Task.sleep(for: .seconds(1.0))

            for route in AppRoute.allCases {
                state.route = route
                try? await Task.sleep(for: .seconds(1.1))
                capture(route: route, to: directory)
            }

            try? await Task.sleep(for: .seconds(0.5))
            NSApp.terminate(nil)
        }

        _ = context
    }

    // MARK: - Offscreen-рендер

    private static func runOffscreen(container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        let directory = snapshotDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let requestedRoute: AppRoute? =
            arguments
            .first(where: { $0.hasPrefix("--offscreen-route=") })
            .flatMap { AppRoute(rawValue: $0.replacingOccurrences(of: "--offscreen-route=", with: "")) }

        let allRoutes: [(AppRoute, AnyView)] = [
            (.dashboard, AnyView(DashboardView())),
            (.recurring, AnyView(RecurringView())),
            (.subscriptions, AnyView(SubscriptionsView())),
            (.analytics, AnyView(AnalyticsView())),
            (.settings, AnyView(SettingsView())),
        ]

        let routes =
            requestedRoute.map { route in
                allRoutes.filter { $0.0 == route }
            } ?? allRoutes

        let isDark = arguments.contains("--dark")
        let size = NSSize(width: 1_105, height: 2_600)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))

            for (route, view) in routes {
                let content =
                    view
                    .frame(width: size.width)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .modelContainer(container)
                    .environment(\.colorScheme, isDark ? .dark : .light)

                let hostingView = NSHostingView(rootView: content)
                hostingView.frame = NSRect(origin: .zero, size: size)
                hostingView.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
                hostingView.layoutSubtreeIfNeeded()
                hostingView.needsDisplay = true

                RunLoop.main.run(until: Date().addingTimeInterval(0.7))

                hostingView.layoutSubtreeIfNeeded()
                hostingView.displayIfNeeded()

                captureOffscreen(
                    hostingView,
                    name: "\(route.rawValue)-tall.png",
                    directory: directory
                )
            }

            try? await Task.sleep(for: .seconds(0.3))
            NSApp.terminate(nil)
        }
    }

    private static func captureOffscreen(_ view: NSView, name: String, directory: URL) {
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1,
            let representation = view.bitmapImageRepForCachingDisplay(in: bounds)
        else {
            return
        }

        view.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }

        try? data.write(to: directory.appendingPathComponent(name))
    }

    // MARK: - Снимок окна

    private static func snapshotDirectory() -> URL {
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--snapshot-dir=") }) {
            let path = argument.replacingOccurrences(of: "--snapshot-dir=", with: "")
            if !path.isEmpty {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("finances-snapshots", isDirectory: true)
    }

    private static func capture(route: AppRoute, to directory: URL) {
        guard
            let window = NSApp.keyWindow
                ?? NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
            let contentView = window.contentView
        else {
            return
        }

        let withChrome = ProcessInfo.processInfo.arguments.contains("--with-chrome")
        let view = withChrome ? (contentView.superview ?? contentView) : contentView

        view.layoutSubtreeIfNeeded()
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1,
            let representation = view.bitmapImageRepForCachingDisplay(in: bounds)
        else {
            return
        }

        view.cacheDisplay(in: bounds, to: representation)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            return
        }

        let suffix = withChrome ? "-chrome" : ""
        let file = directory.appendingPathComponent("\(route.rawValue)\(suffix).png")
        try? data.write(to: file)
    }
}

#endif
