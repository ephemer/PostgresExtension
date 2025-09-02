// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PostgresExtension",
    platforms: [
        .macOS(.v26) // for InlineArray
    ],
    products: [
        .library(
            name: "PostgresExtension",
            targets: ["PostgresExtension"]),
    ],
    targets: [
        .target(name: "CPostgres"),
        .target(
            name: "PostgresExtension",
            dependencies: ["CPostgres"]
        ),
        .testTarget(
            name: "PostgresExtensionTests",
            dependencies: ["PostgresExtension"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
