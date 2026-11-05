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
    name: "MothImport",

    defaultLocalization: "en-GB",

    platforms: [.macOS("27.2"), .iOS("27.2")],

    products: [
        .library(name: "MothImport", targets: ["MothImport"])
    ],

    dependencies: [
        .package(path: "../MothCore"),
        .package(path: "../PostmanKit")
    ],

    targets: [
        .target(name: "MothImport", dependencies: ["MothCore", "PostmanKit"], swiftSettings: swiftSettings),
        .testTarget(name: "MothImportTests", dependencies: ["MothImport", "MothCore"], swiftSettings: swiftSettings)
    ]
)
