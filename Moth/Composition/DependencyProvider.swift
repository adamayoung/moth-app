//  DependencyProvider.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import OSLog

struct DependencyProvider {

    private struct SimulatedStoreFailure: Error {}

    static let uiTestImportFileKey = "MOTH_UI_TEST_IMPORT_FILE"

    /// `App.main()` calls a parameterless `init()`, so the launcher and the `App` can only share one graph here.
    static let currentOutcome = makeCurrentOutcome()

    static var current: DependencyProvider {
        guard case .ready(let provider) = currentOutcome else {
            preconditionFailure("The launcher starts an App that reads the graph only after a ready launch.")
        }
        return provider
    }

    let launchMode: AppLaunchMode
    let dependencies: any AppDependencies

    init(
        launchMode: AppLaunchMode,
        infoDictionary: [String: Any],
        signature: AppSignature,
        environment: [String: String] = [:],
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
        case .uiTesting:
            try SeededAppDependencies(
                seed: SeedData.workspace,
                importFile: environment[Self.uiTestImportFileKey].map { Data($0.utf8) }
            )
        case .demo: try SeededAppDependencies(seed: SeedData.workspace, clipboard: .general)
        case .uiTestingRestoringTabs: try SeededAppDependencies(seed: SeedData.workspace, restoresTabs: true)
        case .uiTestingWithICloudSync: try SeededAppDependencies(seed: SeedData.workspace, isSyncedToICloud: true)
        case .uiTestingStoreFailure: throw SimulatedStoreFailure()
        case .testHost: try SeededAppDependencies(seed: nil)
        }
    }

    static func outcome(
        launchMode: AppLaunchMode,
        infoDictionary: [String: Any],
        signature: AppSignature,
        environment: [String: String] = [:],
        openLiveDataModel: (_ containerIdentifier: String?) throws -> DataModel
    ) throws(LaunchConfigurationError) -> LaunchOutcome {
        do {
            return try .ready(
                DependencyProvider(
                    launchMode: launchMode,
                    infoDictionary: infoDictionary,
                    signature: signature,
                    environment: environment,
                    openLiveDataModel: openLiveDataModel
                )
            )
        } catch let error as LaunchConfigurationError {
            throw error
        } catch {
            let failure = LaunchConfigurationError.storeUnavailable(detail: String(describing: error))
            guard launchMode.showsStoreFailureAlert else {
                throw failure
            }
            report(failure)
            return .storeFailure(StoreFailureAlert(cause: error))
        }
    }

    private static func makeCurrentOutcome() -> LaunchOutcome {
        do {
            return try outcome(
                launchMode: resolveLaunchMode(),
                infoDictionary: Bundle.main.infoDictionary ?? [:],
                signature: .current(),
                environment: ProcessInfo.processInfo.environment,
                openLiveDataModel: openLiveDataModel
            )
        } catch {
            stopLaunch(error)
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
                do {
                    try CloudKitSchemaInitialiser.initialise(
                        containerIdentifier: containerIdentifier,
                        directory: directory
                    )
                } catch {
                    throw LaunchConfigurationError.storeUnavailable(detail: String(describing: error))
                }
            }
        #endif
        return try DataModel(location: .directory(directory), containerIdentifier: containerIdentifier)
    }

    /// `fatalError` would leave a crash dialog on screen, which blocks every UI test run on the machine.
    private static func stopLaunch(_ error: LaunchConfigurationError) -> Never {
        report(error)
        exit(EX_USAGE)
    }

    /// A launch from Finder has no stderr, so the reason is logged as well.
    private static func report(_ error: LaunchConfigurationError) {
        Logger.composition.fault("Moth stopped at launch: \(error.message, privacy: .public)")
        FileHandle.standardError.write(Data("Moth: \(error.message)\n".utf8))
    }

}
