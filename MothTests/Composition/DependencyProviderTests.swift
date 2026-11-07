//  DependencyProviderTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import AppKit
import Foundation
@testable import HTTPKit
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct DependencyProviderTests {

    private struct OpenFailure: Error {}

    private nonisolated static let seededModes: [AppLaunchMode] = [
        .uiTesting, .uiTestingWithICloudSync, .uiTestingRestoringTabs, .demo, .testHost
    ]
    private nonisolated static let allModes: [AppLaunchMode] = [.live] + seededModes
    private static let importFileEnvironment = [DependencyProvider.uiTestImportFileKey: "{}"]

    private let adHoc = AppSignature(teamIdentifier: nil, keychainAccessGroup: nil)
    private let teamSigned = AppSignature(teamIdentifier: "ABCDE12345", keychainAccessGroup: nil)

    @Test("A live launch gets the live graph")
    func liveLaunchGetsLiveGraph() throws {
        #expect(try dependencies(for: .live) is LiveAppDependencies)
    }

    @Test("Every other launch gets the seeded graph", arguments: seededModes)
    func otherLaunchesGetSeededGraph(mode: AppLaunchMode) throws {
        #expect(try dependencies(for: mode) is SeededAppDependencies)
    }

    @Test("The live graph uses the real transport")
    func liveGraphUsesRealTransport() throws {
        #expect(try dependencies(for: .live).transport is URLSessionHTTPTransport)
    }

    @Test("A seeded graph uses the stub transport", arguments: seededModes)
    func seededGraphUsesStubTransport(mode: AppLaunchMode) throws {
        #expect(try dependencies(for: mode).transport is StubHTTPTransport)
    }

    @Test("A team-signed live launch keeps secrets in the Keychain")
    func teamSignedLiveLaunchUsesKeychain() throws {
        let dependencies = try provider(for: .live, signature: teamSigned).dependencies

        #expect(dependencies.secretStore is KeychainSecretStore)
    }

    @Test("A seeded launch keeps secrets in memory, however the build is signed", arguments: seededModes)
    func seededLaunchUsesInMemorySecretStore(mode: AppLaunchMode) throws {
        let dependencies = try provider(for: mode, signature: teamSigned).dependencies

        #expect(dependencies.secretStore is InMemorySecretStore)
    }

    @Test("A seeded graph has no iCloud container", arguments: seededModes)
    func seededGraphHasNoICloudContainer(mode: AppLaunchMode) throws {
        #expect(try dependencies(for: mode).iCloudContainerIdentifier == nil)
    }

    @Test("A seeded graph does not sync", arguments: [AppLaunchMode.uiTesting, .demo, .testHost])
    func seededGraphDoesNotSync(mode: AppLaunchMode) throws {
        #expect(try !dependencies(for: mode).isSyncedToICloud)
    }

    @Test("A seeded graph never touches the live tab state", arguments: seededModes)
    func seededGraphKeepsItsOwnTabKey(mode: AppLaunchMode) throws {
        let live = try dependencies(for: .live).requestTabStore
        let seeded = try dependencies(for: mode).requestTabStore

        #expect(seeded.key != live.key)
    }

    @Test("The UI test launch with iCloud sync reports it as on")
    func uiTestingWithICloudSyncIsSynced() throws {
        #expect(try dependencies(for: .uiTestingWithICloudSync).isSyncedToICloud)
    }

    @Test("A seeded graph's stores are in memory", arguments: seededModes)
    func seededGraphStoresAreInMemory(mode: AppLaunchMode) throws {
        let configurations = try dependencies(for: mode).dataModel.container.configurations
        let isAllInMemory = configurations.allSatisfy(\.isStoredInMemoryOnly)

        #expect(isAllInMemory)
    }

    @Test("A seeded launch never opens the live store", arguments: seededModes)
    func seededLaunchLeavesTheLiveStoreAlone(mode: AppLaunchMode) throws {
        let provider = try DependencyProvider(
            launchMode: mode,
            infoDictionary: [:],
            signature: adHoc,
            openLiveDataModel: { _ in throw OpenFailure() }
        )

        #expect(provider.dependencies is SeededAppDependencies)
    }

    @Test("A UI test launch takes its import file from the environment")
    func uiTestLaunchTakesItsImportFile() throws {
        let dependencies = try provider(for: .uiTesting, environment: Self.importFileEnvironment).dependencies

        #expect(dependencies.importFileSource == .uiTest(Data("{}".utf8)))
    }

    @Test("A UI test launch with no import file uses the panel")
    func uiTestLaunchWithNoFileUsesThePanel() throws {
        #expect(try dependencies(for: .uiTesting).importFileSource == .panel)
    }

    @Test(
        "Every other launch uses the panel, whatever the environment says",
        arguments: [AppLaunchMode.live, .uiTestingWithICloudSync, .uiTestingRestoringTabs, .demo, .testHost]
    )
    func otherLaunchesIgnoreTheImportFile(mode: AppLaunchMode) throws {
        let dependencies = try provider(for: mode, environment: Self.importFileEnvironment).dependencies

        #expect(dependencies.importFileSource == .panel)
    }

    @Test(
        "A UI test launch copies to its own pasteboard",
        arguments: [AppLaunchMode.uiTesting, .uiTestingWithICloudSync, .uiTestingRestoringTabs]
    )
    func uiTestLaunchKeepsOffTheGeneralPasteboard(mode: AppLaunchMode) throws {
        let clipboard = try dependencies(for: mode).clipboard

        #expect(clipboard.pasteboard.name == NSPasteboard.Name("MothUITestClipboard"))
    }

    @Test("A demo launch copies to the General pasteboard, because a person is using it")
    func demoLaunchUsesTheGeneralPasteboard() throws {
        #expect(try dependencies(for: .demo).clipboard.pasteboard.name == .general)
    }

    @Test("A live store that will not open stops the graph being built")
    func liveStoreFailureThrows() {
        #expect(throws: OpenFailure.self) {
            try DependencyProvider(
                launchMode: .live,
                infoDictionary: [:],
                signature: adHoc,
                openLiveDataModel: { _ in throw OpenFailure() }
            )
        }
    }

    @Test("A provider returns one graph across reads", arguments: allModes)
    func providerKeepsItsGraph(mode: AppLaunchMode) throws {
        let provider = try provider(for: mode)

        #expect(provider.dependencies === provider.dependencies)
    }

    @Test("A graph returns one secret store across reads", arguments: allModes)
    func graphKeepsItsSecretStore(mode: AppLaunchMode) throws {
        let dependencies = try dependencies(for: mode)

        #expect((dependencies.secretStore as AnyObject) === (dependencies.secretStore as AnyObject))
    }

    @Test("A graph returns one data model across reads", arguments: allModes)
    func graphKeepsItsDataModel(mode: AppLaunchMode) throws {
        let dependencies = try dependencies(for: mode)

        #expect(dependencies.dataModel === dependencies.dataModel)
    }

    @Test("A seeded graph returns one transport across reads", arguments: seededModes)
    func seededGraphKeepsItsTransport(mode: AppLaunchMode) throws {
        let dependencies = try dependencies(for: mode)

        #expect((dependencies.transport as AnyObject) === (dependencies.transport as AnyObject))
    }

    @Test("The live graph returns one URL session across reads")
    func liveGraphKeepsItsSession() throws {
        let dependencies = try dependencies(for: .live)

        let first = try #require(dependencies.transport as? URLSessionHTTPTransport)
        let second = try #require(dependencies.transport as? URLSessionHTTPTransport)

        #expect(first.session === second.session)
    }

    private func dependencies(for mode: AppLaunchMode) throws -> any AppDependencies {
        try provider(for: mode).dependencies
    }

    private func provider(
        for mode: AppLaunchMode,
        signature: AppSignature? = nil,
        environment: [String: String] = [:]
    ) throws -> DependencyProvider {
        try DependencyProvider(
            launchMode: mode,
            infoDictionary: [:],
            signature: signature ?? adHoc,
            environment: environment,
            openLiveDataModel: { _ in try .inMemory() }
        )
    }

}
