//  LaunchOutcomeTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@Model
private final nonisolated class AddedInNewerSchema {

    var name = "newer data"

    init() {}

}

@MainActor
struct LaunchOutcomeTests {

    private struct OpenFailure: Error {}

    private static let expectedMessage =
        "Quit, then open Moth again. If this keeps happening, the data may come from a newer version of Moth."

    private static let newerSchemaMessage =
        "This data was saved by a newer version of Moth. Update Moth to open it. Your data has not been changed."

    private let adHoc = AppSignature(teamIdentifier: nil, keychainAccessGroup: nil)

    @Test("A live store that will not open gives the alert, with its exact title and message")
    func liveStoreFailureGivesTheAlert() throws {
        let outcome = try outcome(for: .live) { _ in throw OpenFailure() }

        guard case .storeFailure(let alert) = outcome else {
            Issue.record("Expected a store failure, got \(outcome)")
            return
        }
        #expect(alert.title == "Moth can’t open your data.")
        #expect(alert.message == Self.expectedMessage)
        #expect(alert.quitButton == "Quit")
    }

    @Test("A live store that opens gives a ready launch")
    func liveStoreThatOpensIsReady() throws {
        let outcome = try outcome(for: .live) { _ in try .inMemory() }

        guard case .ready(let provider) = outcome else {
            Issue.record("Expected a ready launch, got \(outcome)")
            return
        }
        #expect(provider.launchMode == .live)
    }

    @Test("A launch configuration mistake stops the launch rather than showing the alert")
    func configurationErrorIsNotAStoreFailure() {
        #expect(throws: LaunchConfigurationError.cloudKitSchemaNeedsContainer) {
            try outcome(for: .live) { _ in
                throw LaunchConfigurationError.cloudKitSchemaNeedsContainer
            }
        }
    }

    @Test("Store files that cannot be read stay exactly as they were")
    func unreadableStoreFilesAreLeftInPlace() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for name in ["Synced.store", "Local.store"] {
            try Data("not a store".utf8).write(to: directory.appending(path: name))
        }
        let before = try Self.contents(of: directory)

        let outcome = try outcome(for: .live) { identifier in
            try DataModel(location: .directory(directory), containerIdentifier: identifier)
        }

        #expect(Self.alertMessage(outcome) == Self.expectedMessage)
        #expect(try Self.contents(of: directory) == before)
    }

    @Test("A store from a newer schema says so in the alert and stays exactly as it was")
    func newerStoreGivesTheNewerSchemaMessage() throws {
        let directory = try Self.makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Self.writeNewerStore(named: "Local", in: directory)
        let before = try Self.contents(of: directory)

        let outcome = try outcome(for: .live) { identifier in
            try DataModel(location: .directory(directory), containerIdentifier: identifier)
        }

        #expect(Self.alertMessage(outcome) == Self.newerSchemaMessage)
        #expect(try Self.contents(of: directory) == before)
    }

    @Test("A UI test's simulated failure takes the same path as a live one")
    func simulatedFailureGivesTheAlert() throws {
        let outcome = try outcome(for: .uiTestingStoreFailure) { _ in try .inMemory() }

        #expect(Self.isStoreFailure(outcome))
    }

    @Test(
        "Only a launch with a real or simulated store failure shows the alert",
        arguments: [
            (AppLaunchMode.live, true),
            (AppLaunchMode.uiTestingStoreFailure, true),
            (AppLaunchMode.uiTesting, false),
            (AppLaunchMode.uiTestingWithICloudSync, false),
            (AppLaunchMode.demo, false),
            (AppLaunchMode.testHost, false)
        ]
    )
    func alertModes(mode: AppLaunchMode, showsAlert: Bool) {
        #expect(mode.showsStoreFailureAlert == showsAlert)
    }

    private func outcome(
        for mode: AppLaunchMode,
        openLiveDataModel: (_ containerIdentifier: String?) throws -> DataModel
    ) throws -> LaunchOutcome {
        try DependencyProvider.outcome(
            launchMode: mode,
            infoDictionary: [:],
            signature: adHoc,
            openLiveDataModel: openLiveDataModel
        )
    }

    private static func isStoreFailure(_ outcome: LaunchOutcome) -> Bool {
        if case .storeFailure = outcome {
            return true
        }
        return false
    }

    private static func alertMessage(_ outcome: LaunchOutcome) -> String? {
        if case .storeFailure(let alert) = outcome {
            return alert.message
        }
        return nil
    }

    private static func writeNewerStore(named name: String, in directory: URL) throws {
        let schema = Schema([AddedInNewerSchema.self], version: Schema.Version(2, 0, 0))
        let configuration = ModelConfiguration(
            name,
            schema: schema,
            url: directory.appending(path: "\(name).store"),
            cloudKitDatabase: .none
        )
        _ = try ModelContainer(for: schema, configurations: configuration)
    }

    private static func makeDirectory() throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func contents(of directory: URL) throws -> [String: Data] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try Dictionary(uniqueKeysWithValues: urls.map { url in
            try (url.lastPathComponent, Data(contentsOf: url))
        })
    }

}
