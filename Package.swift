// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Finances",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Finances", targets: ["FinancesApp"])
    ],
    targets: [
        .target(
            name: "FinancesCore",
            path: "Sources/FinancesCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "FinancesUI",
            dependencies: ["FinancesCore"],
            path: "Sources/FinancesUI",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "FinancesApp",
            dependencies: ["FinancesCore", "FinancesUI"],
            path: "Sources/FinancesApp",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "FinancesCoreTests",
            dependencies: ["FinancesCore"],
            path: "Tests/FinancesCoreTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
