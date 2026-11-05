//  DependencyProvider.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

struct DependencyProvider {

    /// `App.main()` calls a parameterless `init()`, so the launcher and the `App` can only share one graph here.
    static let current = DependencyProvider(
        launchMode: resolveLaunchMode(),
        infoDictionary: Bundle.main.infoDictionary ?? [:],
        signature: .current()
    )

    let launchMode: AppLaunchMode
    let dependencies: any AppDependencies

    init(launchMode: AppLaunchMode, infoDictionary: [String: Any], signature: AppSignature) {
        self.launchMode = launchMode
        self.dependencies = switch launchMode {
        case .live: LiveAppDependencies(infoDictionary: infoDictionary, signature: signature)
        case .uiTesting, .demo, .testHost: SeededAppDependencies()
        }
    }

    private static func resolveLaunchMode() -> AppLaunchMode {
        let process = ProcessInfo.processInfo
        do {
            return try AppLaunchMode(
                arguments: process.arguments,
                defaults: .standard,
                environment: process.environment
            )
        } catch {
            stopLaunch(error)
        }
    }

    /// `fatalError` would leave a crash dialog on screen, which blocks every UI test run on the machine.
    private static func stopLaunch(_ error: LaunchConfigurationError) -> Never {
        FileHandle.standardError.write(Data("Moth: \(error.message)\n".utf8))
        exit(EX_USAGE)
    }

}
