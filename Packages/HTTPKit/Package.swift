// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .treatAllWarnings(as: .error)
]

let package = Package(
    name: "HTTPKit",

    defaultLocalization: "en-GB",

    platforms: [.macOS("27.2"), .iOS("27.2")],

    products: [
        .library(name: "HTTPKit", targets: ["HTTPKit"])
    ],

    targets: [
        .target(name: "HTTPKit", swiftSettings: swiftSettings),
        .testTarget(name: "HTTPKitTests", dependencies: ["HTTPKit"], swiftSettings: swiftSettings)
    ]
)
