//  DependencyProvider.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import OSLog

struct DependencyProvider {

    /// `App.main()` calls a parameterless `init()`, so the launcher and the `App` can only share one graph here.
    static let current = makeCurrent()

    let launchMode: AppLaunchMode
    let dependencies: any AppDependencies

    init(
        launchMode: AppLaunchMode,
        infoDictionary: [String: Any],
        signature: AppSignature,
        openLiveDataModel: (_ containerIdentifier: String?) throws -> DataModel
    ) throws {
        self.launchMode = launchMode
        self.dependencies = switch launchMode {
        case .live:
            try LiveAppDependencies(
                infoDictionary: infoDictionary,
                signature: signature,
                openDataModel: openLiveDataModel
            )
        case .uiTesting, .demo: try SeededAppDependencies(seed: SeedData.workspace)
        case .testHost: try SeededAppDependencies(seed: nil)
        }
    }

    private static func makeCurrent() -> DependencyProvider {
        do {
            return try DependencyProvider(
                launchMode: resolveLaunchMode(),
                infoDictionary: Bundle.main.infoDictionary ?? [:],
                signature: .current(),
                openLiveDataModel: openLiveDataModel
            )
        } catch let error as LaunchConfigurationError {
            stopLaunch(error)
        } catch {
            stopLaunch(.storeUnavailable(detail: String(describing: error)))
        }
    }

    private static func resolveLaunchMode() throws(LaunchConfigurationError) -> AppLaunchMode {
        let process = ProcessInfo.processInfo
        return try AppLaunchMode(
            arguments: process.arguments,
            defaults: .standard,
            environment: process.environment
        )
    }

    private static func openLiveDataModel(containerIdentifier: String?) throws -> DataModel {
        let directory = URL.applicationSupportDirectory.appending(path: "Moth", directoryHint: .isDirectory)
        #if DEBUG
            if try AppLaunchMode.initialisesCloudKitSchema(arguments: ProcessInfo.processInfo.arguments) {
                guard let containerIdentifier else {
                    throw LaunchConfigurationError.cloudKitSchemaNeedsContainer
                }
                try CloudKitSchemaInitialiser.initialise(containerIdentifier: containerIdentifier, directory: directory)
            }
        #endif
        return try DataModel(location: .directory(directory), containerIdentifier: containerIdentifier)
    }

    /// `fatalError` would leave a crash dialog on screen, which blocks every UI test run on the machine. A launch from
    /// Finder has no stderr, so the reason is logged as well.
    private static func stopLaunch(_ error: LaunchConfigurationError) -> Never {
        Logger.composition.fault("Moth stopped at launch: \(error.message, privacy: .public)")
        FileHandle.standardError.write(Data("Moth: \(error.message)\n".utf8))
        exit(EX_USAGE)
    }

}
