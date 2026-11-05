//  DataModelTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import SwiftData
import Testing

struct DataModelTests {

    @Test("An in-memory data model opens both stores, with neither on CloudKit")
    func inMemoryOpensBothStores() throws {
        let dataModel = try DataModel.inMemory()

        let configurations = dataModel.container.configurations
        let isAllInMemory = configurations.allSatisfy(\.isStoredInMemoryOnly)
        let isOffCloudKit = configurations.allSatisfy { $0.cloudKitContainerIdentifier == nil }

        #expect(configurations.count == 2)
        #expect(isAllInMemory)
        #expect(isOffCloudKit)
    }

    @Test("The main context does not save on its own")
    func mainContextDoesNotAutosave() throws {
        let dataModel = try DataModel.inMemory()

        #expect(!dataModel.mainContext.autosaveEnabled)
    }

    @Test("A seed is in the store before the first read")
    func seedLoadsSynchronously() throws {
        let seed = DomainFixtures.workspace()
        let dataModel = try DataModel.inMemory(seed: seed)

        let rows = try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>())

        #expect(try rows.map { try $0.asDomain() } == [seed])
    }

    @Test("With no seed, a store starts empty")
    func noSeedStartsEmpty() throws {
        let dataModel = try DataModel.inMemory()

        #expect(try dataModel.mainContext.fetch(FetchDescriptor<WorkspaceModel>()).isEmpty)
    }

    @Test("A data model reads back what it wrote after reopening on disk")
    func onDiskStoresPersist() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DataModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collection = DomainFixtures.collection()
        let entry = DomainFixtures.historyEntry()

        do {
            let dataModel = try DataModel(location: .directory(directory), containerIdentifier: nil)
            try await dataModel.writer.createCollection(collection)
            try await dataModel.writer.addHistoryEntry(entry)
        }

        let reopened = try DataModel(location: .directory(directory), containerIdentifier: nil)
        let workspaces = try reopened.mainContext.fetch(FetchDescriptor<WorkspaceModel>())
        let history = try reopened.mainContext.fetch(FetchDescriptor<HistoryEntryModel>())
        #expect(try workspaces.map { try $0.asDomain().collections } == [[collection]])
        #expect(try history.map { try $0.asDomain() } == [entry])
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Synced.store").path()))
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "Local.store").path()))
    }

}
