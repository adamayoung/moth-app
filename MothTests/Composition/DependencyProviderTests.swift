//  DependencyProviderTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import HTTPKit
@testable import Moth
import MothCore
import Testing

@MainActor
struct DependencyProviderTests {

    private nonisolated static let seededModes: [AppLaunchMode] = [.uiTesting, .demo, .testHost]
    private nonisolated static let allModes: [AppLaunchMode] = [.live] + seededModes

    @Test("A live launch gets the live graph")
    func liveLaunchGetsLiveGraph() {
        #expect(dependencies(for: .live) is LiveAppDependencies)
    }

    @Test("Every other launch gets the seeded graph", arguments: seededModes)
    func otherLaunchesGetSeededGraph(mode: AppLaunchMode) {
        #expect(dependencies(for: mode) is SeededAppDependencies)
    }

    @Test("The live graph uses the real transport")
    func liveGraphUsesRealTransport() {
        #expect(dependencies(for: .live).transport is URLSessionHTTPTransport)
    }

    @Test("A seeded graph uses the stub transport", arguments: seededModes)
    func seededGraphUsesStubTransport(mode: AppLaunchMode) {
        #expect(dependencies(for: mode).transport is StubHTTPTransport)
    }

    @Test("Every graph keeps secrets in memory until the Keychain store arrives", arguments: allModes)
    func everyGraphUsesInMemorySecretStore(mode: AppLaunchMode) {
        #expect(dependencies(for: mode).secretStore is InMemorySecretStore)
    }

    @Test("A seeded graph has no iCloud container", arguments: seededModes)
    func seededGraphHasNoICloudContainer(mode: AppLaunchMode) {
        #expect(dependencies(for: mode).iCloudContainerIdentifier == nil)
    }

    @Test("A provider returns one graph across reads", arguments: allModes)
    func providerKeepsItsGraph(mode: AppLaunchMode) {
        let provider = DependencyProvider(launchMode: mode, infoDictionary: [:])

        #expect(provider.dependencies === provider.dependencies)
    }

    @Test("A graph returns one secret store across reads", arguments: allModes)
    func graphKeepsItsSecretStore(mode: AppLaunchMode) {
        let dependencies = dependencies(for: mode)

        #expect((dependencies.secretStore as AnyObject) === (dependencies.secretStore as AnyObject))
    }

    @Test("A seeded graph returns one transport across reads", arguments: seededModes)
    func seededGraphKeepsItsTransport(mode: AppLaunchMode) {
        let dependencies = dependencies(for: mode)

        #expect((dependencies.transport as AnyObject) === (dependencies.transport as AnyObject))
    }

    @Test("The live graph returns one URL session across reads")
    func liveGraphKeepsItsSession() throws {
        let dependencies = dependencies(for: .live)

        let first = try #require(dependencies.transport as? URLSessionHTTPTransport)
        let second = try #require(dependencies.transport as? URLSessionHTTPTransport)

        #expect(first.session === second.session)
    }

    private func dependencies(for mode: AppLaunchMode) -> any AppDependencies {
        DependencyProvider(launchMode: mode, infoDictionary: [:]).dependencies
    }

}
