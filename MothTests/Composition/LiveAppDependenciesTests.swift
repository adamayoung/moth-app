//  LiveAppDependenciesTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

@testable import Moth
import Testing

@MainActor
struct LiveAppDependenciesTests {

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
