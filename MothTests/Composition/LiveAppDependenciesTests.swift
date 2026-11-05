//  LiveAppDependenciesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import HTTPKit
@testable import Moth
@testable import MothCore
import SwiftData
import Testing

@MainActor
struct LiveAppDependenciesTests {

    private struct OpenFailure: Error {}

    private let adHoc = AppSignature(teamIdentifier: nil, keychainAccessGroup: nil)
    private let teamSigned = AppSignature(teamIdentifier: "ABCDE12345", keychainAccessGroup: nil)
    private let teamSignedForICloud = AppSignature(
        teamIdentifier: "ABCDE12345",
        keychainAccessGroup: "ABCDE12345.moth"
    )

    @Test("The live session carries no cached response, cookie or credential from one request to the next")
    func liveSessionKeepsNoState() throws {
        let dependencies = try makeDependencies(infoDictionary: [:], signature: adHoc)
        let transport = try #require(dependencies.transport as? URLSessionHTTPTransport)

        let configuration = transport.session.configuration

        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test("A configured iCloud container identifier is read from the Info.plist")
    func presentIdentifierIsRead() throws {
        let dependencies = try makeDependencies(
            infoDictionary: ["MothICloudContainer": "iCloud.uk.co.adam-young.Moth"],
            signature: adHoc
        )

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.uk.co.adam-young.Moth")
    }

    @Test("Whitespace around an iCloud container identifier is removed")
    func surroundingWhitespaceIsRemoved() throws {
        let dependencies = try makeDependencies(
            infoDictionary: ["MothICloudContainer": " iCloud.moth\n"],
            signature: adHoc
        )

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.moth")
    }

    @Test("An empty or whitespace-only iCloud container counts as none", arguments: ["", "   ", "\n\t"])
    func blankIdentifierCountsAsNone(value: String) throws {
        let dependencies = try makeDependencies(infoDictionary: ["MothICloudContainer": value], signature: adHoc)

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

    @Test("A missing iCloud container counts as none")
    func missingIdentifierCountsAsNone() throws {
        let dependencies = try makeDependencies(infoDictionary: [:], signature: adHoc)

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

    @Test("An ad hoc build keeps secrets in memory, with or without a container", arguments: ["", "iCloud.moth"])
    func adHocBuildKeepsSecretsInMemory(container: String) throws {
        let dependencies = try makeDependencies(infoDictionary: ["MothICloudContainer": container], signature: adHoc)

        #expect(dependencies.secretStore is InMemorySecretStore)
    }

    @Test("A team-signed build with no container keeps secrets on this Mac")
    func teamSignedBuildWithoutContainerStaysLocal() throws {
        let dependencies = try makeDependencies(infoDictionary: [:], signature: teamSigned)

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.mode == .localOnly)
    }

    @Test("A team-signed build with a container synchronises secrets through its access group")
    func teamSignedBuildWithContainerSynchronises() throws {
        let dependencies = try makeDependencies(
            infoDictionary: ["MothICloudContainer": "iCloud.moth"],
            signature: teamSignedForICloud
        )

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.mode == .synchronised(accessGroup: "ABCDE12345.moth"))
    }

    @Test("A signed build's service name holds its team, because reading another team's item would prompt")
    func keychainServiceHoldsTheTeam() throws {
        let dependencies = try makeDependencies(infoDictionary: [:], signature: teamSigned)

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.service == "uk.co.adam-young.Moth.secrets.ABCDE12345")
    }

    @Test("The stores open with the configured iCloud container", arguments: [
        ("iCloud.moth", "iCloud.moth"),
        ("", nil)
    ] as [(String, String?)])
    func storesOpenWithTheContainer(configured: String, expected: String?) throws {
        var opened: [String?] = []

        _ = try LiveAppDependencies(
            infoDictionary: ["MothICloudContainer": configured],
            signature: adHoc,
            openDataModel: { identifier in
                opened.append(identifier)
                return try .inMemory()
            }
        )

        #expect(opened == [expected])
    }

    @Test("A store that will not open is an error")
    func storeFailureThrows() {
        #expect(throws: OpenFailure.self) {
            try LiveAppDependencies(
                infoDictionary: [:],
                signature: adHoc,
                openDataModel: { _ in throw OpenFailure() }
            )
        }
    }

    @Test("A live launch merges the workspaces sync left behind")
    func liveLaunchMergesDuplicateWorkspaces() async throws {
        let dataModel = try DataModel.inMemory()
        let context = ModelContext(dataModel.container)
        try context.insert(WorkspaceModel(Workspace()))
        try context.insert(WorkspaceModel(Workspace()))
        try context.save()

        let dependencies = try LiveAppDependencies(
            infoDictionary: [:],
            signature: adHoc,
            openDataModel: { _ in dataModel }
        )
        await dependencies.launchReconcile.value

        let workspaces = try ModelContext(dataModel.container).fetch(FetchDescriptor<WorkspaceModel>())
        #expect(workspaces.count == 1)
    }

    private func makeDependencies(
        infoDictionary: [String: Any],
        signature: AppSignature
    ) throws -> LiveAppDependencies {
        try LiveAppDependencies(
            infoDictionary: infoDictionary,
            signature: signature,
            openDataModel: { _ in try .inMemory() }
        )
    }

}
