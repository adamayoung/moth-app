//  LiveAppDependenciesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import HTTPKit
@testable import Moth
import MothCore
import Testing

@MainActor
struct LiveAppDependenciesTests {

    private let adHoc = AppSignature(teamIdentifier: nil, keychainAccessGroup: nil)
    private let teamSigned = AppSignature(teamIdentifier: "ABCDE12345", keychainAccessGroup: "ABCDE12345.moth")

    @Test("The live session carries no cached response, cookie or credential from one request to the next")
    func liveSessionKeepsNoState() throws {
        let dependencies = LiveAppDependencies(infoDictionary: [:], signature: adHoc)
        let transport = try #require(dependencies.transport as? URLSessionHTTPTransport)

        let configuration = transport.session.configuration

        #expect(configuration.urlCache == nil)
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test("A configured iCloud container identifier is read from the Info.plist")
    func presentIdentifierIsRead() {
        let dependencies = LiveAppDependencies(
            infoDictionary: ["MothICloudContainer": "iCloud.uk.co.adam-young.Moth"],
            signature: adHoc
        )

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.uk.co.adam-young.Moth")
    }

    @Test("Whitespace around an iCloud container identifier is removed")
    func surroundingWhitespaceIsRemoved() {
        let dependencies = LiveAppDependencies(
            infoDictionary: ["MothICloudContainer": " iCloud.moth\n"],
            signature: adHoc
        )

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.moth")
    }

    @Test("An empty or whitespace-only iCloud container counts as none", arguments: ["", "   ", "\n\t"])
    func blankIdentifierCountsAsNone(value: String) {
        let dependencies = LiveAppDependencies(infoDictionary: ["MothICloudContainer": value], signature: adHoc)

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

    @Test("A missing iCloud container counts as none")
    func missingIdentifierCountsAsNone() {
        let dependencies = LiveAppDependencies(infoDictionary: [:], signature: adHoc)

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

    @Test("An ad hoc build keeps secrets in memory, with or without a container", arguments: ["", "iCloud.moth"])
    func adHocBuildKeepsSecretsInMemory(container: String) {
        let dependencies = LiveAppDependencies(infoDictionary: ["MothICloudContainer": container], signature: adHoc)

        #expect(dependencies.secretStore is InMemorySecretStore)
    }

    @Test("A team-signed build with no container keeps secrets on this Mac")
    func teamSignedBuildWithoutContainerStaysLocal() throws {
        let dependencies = LiveAppDependencies(infoDictionary: [:], signature: teamSigned)

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.mode == .localOnly)
    }

    @Test("A team-signed build with a container synchronises secrets through its access group")
    func teamSignedBuildWithContainerSynchronises() throws {
        let dependencies = LiveAppDependencies(
            infoDictionary: ["MothICloudContainer": "iCloud.moth"],
            signature: teamSigned
        )

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.mode == .synchronised(accessGroup: "ABCDE12345.moth"))
    }

    @Test("Every signed build keeps its secrets under one service name")
    func keychainServiceIsStable() throws {
        let dependencies = LiveAppDependencies(infoDictionary: [:], signature: teamSigned)

        let store = try #require(dependencies.secretStore as? KeychainSecretStore)

        #expect(store.service == "uk.co.adam-young.Moth.secrets")
    }

}
