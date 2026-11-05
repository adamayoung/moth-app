//  DependencyProvider.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation

struct DependencyProvider {

    /// `App.main()` calls a parameterless `init()`, so the launcher and the `App` can only share one graph here.
    static let current = DependencyProvider(
        launchMode: MothAppLauncher.resolveLaunchMode(),
        infoDictionary: Bundle.main.infoDictionary ?? [:]
    )

    let launchMode: AppLaunchMode
    let dependencies: any AppDependencies

    init(launchMode: AppLaunchMode, infoDictionary: [String: Any]) {
        self.launchMode = launchMode
        self.dependencies = switch launchMode {
        case .live: LiveAppDependencies(infoDictionary: infoDictionary)
        case .uiTesting, .demo, .testHost: SeededAppDependencies()
        }
    }

}
