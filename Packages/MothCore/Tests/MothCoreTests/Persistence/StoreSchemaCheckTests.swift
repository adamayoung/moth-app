//  StoreSchemaCheckTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CoreData
import Foundation
@testable import MothCore
import SwiftData
import Testing

struct StoreSchemaCheckTests {

    @Test("A newer store of either kind stops the launch, and neither store is touched", arguments: StoreKind.allCases)
    func newerStoreIsRefusedAndBothStoresStayIntact(kind: StoreKind) async throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
            try await dataModel.writer.createCollection(DomainFixtures.collection())
            try await dataModel.writer.addHistoryEntry(DomainFixtures.historyEntry())
        }
        try StoreFiles.removeStore(named: kind.storeName, in: directory)
        try CoreDataStoreFixture.makeStore(
            at: directory.appending(path: kind.storeName),
            models: kind.models,
            change: CoreDataStoreFixture.addColumn
        )
        let before = try StoreFiles.contents(of: directory)

        #expect(throws: UnknownStoreSchemaError(storeName: kind.storeName)) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }

        #expect(try StoreFiles.contents(of: directory) == before)
    }

    @Test("A store from a schema that added a model stops the launch")
    func storeWithAnAddedModelIsRefused() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try CoreDataStoreFixture.makeStore(
            at: directory.appending(path: "Synced.store"),
            models: SchemaV1.syncedModels,
            change: CoreDataStoreFixture.addEntity
        )

        #expect(throws: UnknownStoreSchemaError(storeName: "Synced.store")) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }
    }

    @Test("A refused store's unflushed write-ahead log and its index keep every byte")
    func refusedStoreWithAPendingLogKeepsEveryByte() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try CoreDataStoreFixture.makeStoreWithPendingLog(
            at: directory.appending(path: "Synced.store"),
            models: SchemaV1.syncedModels,
            change: CoreDataStoreFixture.addColumn
        )
        let before = try StoreFiles.contents(of: directory)
        #expect(try #require(before["Synced.store-wal"]).isEmpty == false)

        #expect(throws: UnknownStoreSchemaError(storeName: "Synced.store")) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }

        #expect(try StoreFiles.contents(of: directory) == before)
    }

    @Test("A newer store is found in a directory with a space in its name, like Application Support")
    func newerStoreIsFoundWhenThePathNeedsEncoding() throws {
        let parent = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: parent) }
        let directory = parent.appending(path: "Application Support", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try CoreDataStoreFixture.makeStore(
            at: directory.appending(path: "Local.store"),
            models: SchemaV1.localModels,
            change: CoreDataStoreFixture.addColumn
        )

        #expect(throws: UnknownStoreSchemaError(storeName: "Local.store")) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }
    }

    @Test("A store from any version in the plan passes, and one from outside the plan does not")
    func onlyStoresFromAPlannedVersionPass() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let earlier = try Self.makeStore(for: PlannedFixtureV1.self, in: directory)
        let current = try Self.makeStore(for: PlannedFixtureV2.self, in: directory)
        let newer = try Self.makeStore(for: PlannedFixtureV3.self, in: directory)
        let check = StoreSchemaCheck(knownSchemas: [PlannedFixtureV1.self, PlannedFixtureV2.self])

        try check.verify(storesAt: [earlier, current])

        #expect(throws: UnknownStoreSchemaError(storeName: newer.lastPathComponent)) {
            try check.verify(storesAt: [earlier, current, newer])
        }
    }

    @Test("A launch with no store files opens and creates them")
    func noStoreFilesOpens() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)

        #expect(try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).isEmpty)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Synced.store").path()))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Local.store").path()))
    }

    @Test("A launch with one of the two store files opens", arguments: StoreKind.allCases)
    func oneStoreFileOpens(kind: StoreKind) throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        do {
            _ = try DataModel(location: .directory(directory), containerIdentifier: nil)
        }
        try StoreFiles.removeStore(named: kind.storeName, in: directory)

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)

        #expect(try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).isEmpty)
    }

    @Test("A file the check cannot read stops the launch, because SwiftData might still open it")
    func unreadableStoreStopsTheCheck() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appending(path: "Synced.store")
        try Data("not a store".utf8).write(to: store)

        #expect(throws: (any Error).self) {
            try StoreSchemaCheck(knownSchemas: MothMigrationPlan.schemas).verify(storesAt: [store])
        }
    }

    @Test("A store that lists no entities is refused, because nothing shows it is known")
    func storeWithNoEntitiesIsRefused() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try CoreDataStoreFixture.makeStore(
            at: directory.appending(path: "Synced.store"),
            models: SchemaV1.syncedModels,
            change: { $0.entities = [] }
        )

        #expect(throws: UnknownStoreSchemaError(storeName: "Synced.store")) {
            try DataModel(location: .directory(directory), containerIdentifier: nil)
        }
    }

    @Test("An empty store file is left to SwiftData, which starts a new store over it")
    func emptyStoreFileOpens() throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data().write(to: directory.appending(path: "Synced.store"))

        let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)

        #expect(try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).isEmpty)
    }

    #if DEBUG
        @Test("The CloudKit schema initialiser refuses a newer store before it opens it")
        func initialiserRefusesANewerStore() throws {
            let directory = try CharacterisationStore.makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }
            try CoreDataStoreFixture.makeStore(
                at: directory.appending(path: "Synced.store"),
                models: SchemaV1.syncedModels,
                change: CoreDataStoreFixture.addColumn
            )
            let before = try StoreFiles.contents(of: directory)

            #expect(throws: UnknownStoreSchemaError(storeName: "Synced.store")) {
                try CloudKitSchemaInitialiser.initialise(
                    containerIdentifier: "iCloud.example.never-reached",
                    directory: directory
                )
            }

            #expect(try StoreFiles.contents(of: directory) == before)
        }
    #endif

    private static func makeStore(for version: any VersionedSchema.Type, in directory: URL) throws -> URL {
        let schema = Schema(versionedSchema: version)
        let name = "Version\(version.versionIdentifier.major)"
        let configuration = CharacterisationStore.onDiskConfiguration(named: name, schema: schema, in: directory)
        _ = try ModelContainer(for: schema, configurations: configuration)
        return configuration.url
    }

}

enum StoreKind: CaseIterable {

    case synced
    case local

    var storeName: String {
        switch self {
        case .synced: "Synced.store"
        case .local: "Local.store"
        }
    }

    var models: [any PersistentModel.Type] {
        switch self {
        case .synced: SchemaV1.syncedModels
        case .local: SchemaV1.localModels
        }
    }

}
