// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .defaultIsolation(MainActor.self),
    .treatAllWarnings(as: .error)
]

let package = Package(
    name: "MothCore",

    defaultLocalization: "en-GB",

    platforms: [.macOS("27.2"), .iOS("27.2")],

    products: [
        .library(name: "MothCore", targets: ["MothCore"])
    ],

    dependencies: [
        .package(path: "../HTTPKit")
    ],

    targets: [
        .target(
            name: "MothCore",
            dependencies: ["HTTPKit"],
            resources: [.process("Resources")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "MothCoreTests",
            dependencies: ["MothCore", "HTTPKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        )
    ]
)
