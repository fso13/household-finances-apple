// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Finances",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Finances", targets: ["Finances"])
    ],
    targets: [
        .executableTarget(
            name: "Finances",
            path: "Sources/Finances",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
