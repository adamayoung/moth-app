//  StoreConfigurationsTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

/// Reads configurations without opening them: a `.private` container crashes a `swift test` process on teardown,
/// because CloudKit needs a bundle identifier.
struct StoreConfigurationsTests {

    private let directory = URL(filePath: "/tmp/moth-store-configurations", directoryHint: .isDirectory)

    @Test("An in-memory synced store with a container uses that private CloudKit database")
    func inMemorySyncedStoreWithContainer() {
        let configurations = StoreConfigurations(location: .inMemory, containerIdentifier: "iCloud.moth")

        #expect(configurations.synced.isStoredInMemoryOnly)
        #expect(configurations.synced.cloudKitContainerIdentifier == "iCloud.moth")
    }

    @Test("An in-memory synced store with no container uses no CloudKit database")
    func inMemorySyncedStoreWithoutContainer() {
        let configurations = StoreConfigurations(location: .inMemory, containerIdentifier: nil)

        #expect(configurations.synced.isStoredInMemoryOnly)
        #expect(configurations.synced.cloudKitContainerIdentifier == nil)
    }

    @Test("The local store never uses CloudKit", arguments: ["iCloud.moth", nil] as [String?])
    func localStoreNeverSyncs(containerIdentifier: String?) {
        let configurations = StoreConfigurations(location: .inMemory, containerIdentifier: containerIdentifier)

        #expect(configurations.local.isStoredInMemoryOnly)
        #expect(configurations.local.cloudKitContainerIdentifier == nil)
    }

    @Test("On disk, each store has its own file in the directory", arguments: ["iCloud.moth", nil] as [String?])
    func onDiskStoresHaveTheirOwnFiles(containerIdentifier: String?) {
        let configurations = StoreConfigurations(
            location: .directory(directory),
            containerIdentifier: containerIdentifier
        )

        #expect(!configurations.synced.isStoredInMemoryOnly)
        #expect(!configurations.local.isStoredInMemoryOnly)
        #expect(configurations.synced.url == directory.appending(path: "Synced.store"))
        #expect(configurations.local.url == directory.appending(path: "Local.store"))
        #expect(configurations.synced.cloudKitContainerIdentifier == containerIdentifier)
        #expect(configurations.local.cloudKitContainerIdentifier == nil)
    }

    @Test("The two configurations share no model, so a local model cannot reach CloudKit")
    func configurationsShareNoModel() throws {
        let configurations = StoreConfigurations(location: .inMemory, containerIdentifier: nil)

        let synced = try Set(#require(configurations.synced.schema).entities.map(\.name))
        let local = try Set(#require(configurations.local.schema).entities.map(\.name))

        #expect(synced == ["CollectionModel", "EnvironmentModel", "FolderModel", "RequestModel", "VariableModel",
                           "WorkspaceModel"])
        #expect(local == ["CookieModel", "HistoryEntryModel"])
    }

}
