//  LiveAppDependenciesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import HTTPKit
@testable import Moth
import Testing

@MainActor
struct LiveAppDependenciesTests {

    @Test("The live session carries no cached response or cookie from one request to the next")
    func liveSessionKeepsNoState() throws {
        let dependencies = LiveAppDependencies(infoDictionary: [:])
        let transport = try #require(dependencies.transport as? URLSessionHTTPTransport)

        let configuration = transport.session.configuration

        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
    }

    @Test("A configured iCloud container identifier is read from the Info.plist")
    func presentIdentifierIsRead() {
        let dependencies = LiveAppDependencies(infoDictionary: ["MothICloudContainer": "iCloud.uk.co.adam-young.Moth"])

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.uk.co.adam-young.Moth")
    }

    @Test("Whitespace around an iCloud container identifier is removed")
    func surroundingWhitespaceIsRemoved() {
        let dependencies = LiveAppDependencies(infoDictionary: ["MothICloudContainer": " iCloud.moth\n"])

        #expect(dependencies.iCloudContainerIdentifier == "iCloud.moth")
    }

    @Test("An empty or whitespace-only iCloud container counts as none", arguments: ["", "   ", "\n\t"])
    func blankIdentifierCountsAsNone(value: String) {
        let dependencies = LiveAppDependencies(infoDictionary: ["MothICloudContainer": value])

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

    @Test("A missing iCloud container counts as none")
    func missingIdentifierCountsAsNone() {
        let dependencies = LiveAppDependencies(infoDictionary: [:])

        #expect(dependencies.iCloudContainerIdentifier == nil)
    }

}
