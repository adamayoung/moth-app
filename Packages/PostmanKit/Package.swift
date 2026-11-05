// swift-tools-version: 6.4

import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .treatAllWarnings(as: .error)
]

let package = Package(
    name: "PostmanKit",

    defaultLocalization: "en-GB",

    platforms: [.macOS("27.2"), .iOS("27.2")],

    products: [
        .library(name: "PostmanKit", targets: ["PostmanKit"])
    ],

    targets: [
        .target(name: "PostmanKit", swiftSettings: swiftSettings),
        .testTarget(
            name: "PostmanKitTests",
            dependencies: ["PostmanKit"],
            resources: [.copy("Fixtures")],
            swiftSettings: swiftSettings
        )
    ]
)
