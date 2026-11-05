//  SwiftDataStaleSaveCharacterisationTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData
import Testing

@Model
final class StaleSaveRow {
    var title: String = "seeded"
    var notes: String = "seeded"

    init() {}
}

struct RowValues: Equatable {
    var title: String
    var notes: String
}

struct SwiftDataStaleSaveCharacterisationTests {

    @Test(
        "Characterises SwiftData: a stale save of the same property overwrites a second context's change",
        arguments: StoreLocation.allCases
    )
    func characterisesAStaleSaveOfTheSameProperty(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let stale = ModelContext(container)
            let staleRow = try #require(stale.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(staleRow.title == "seeded")

            try Self.changeTitleInASecondContext(of: container)
            staleRow.title = "stale"
            try stale.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "stale", notes: "seeded"))
        }
    }

    @Test(
        "Characterises SwiftData: a stale save of a different property reverts a second context's change",
        arguments: StoreLocation.allCases
    )
    func characterisesAStaleSaveOfADifferentProperty(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let stale = ModelContext(container)
            let staleRow = try #require(stale.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(staleRow.title == "seeded")

            try Self.changeTitleInASecondContext(of: container)
            staleRow.notes = "stale"
            try stale.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "seeded", notes: "stale"))
        }
    }

    @Test(
        "Characterises SwiftData: a long-lived context's fetch by identifier refreshes a held row",
        arguments: StoreLocation.allCases
    )
    func characterisesARefetchInALongLivedContext(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let longLived = ModelContext(container)
            let held = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(held.title == "seeded")

            try Self.changeTitleInASecondContext(of: container)
            let refetched = try Self.fetchRow(held.persistentModelID, in: longLived)
            #expect(refetched === held)
            #expect(held.title == "second")
            refetched.notes = "long-lived"
            try longLived.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "second", notes: "long-lived"))
        }
    }

    @Test(
        "Characterises SwiftData: model(for:) leaves a held row stale, so its save reverts a second context's change",
        arguments: StoreLocation.allCases
    )
    func characterisesModelForInALongLivedContext(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let longLived = ModelContext(container)
            let held = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(held.title == "seeded")

            try Self.changeTitleInASecondContext(of: container)
            let resolved = try #require(longLived.model(for: held.persistentModelID) as? StaleSaveRow)
            #expect(resolved.title == "seeded")
            resolved.notes = "long-lived"
            try longLived.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "seeded", notes: "long-lived"))
        }
    }

    @Test(
        "Characterises SwiftData: a fetch leaves a row with unsaved changes stale, so its save reverts",
        arguments: StoreLocation.allCases
    )
    func characterisesAFetchOverUnsavedChanges(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let longLived = ModelContext(container)
            let held = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            held.notes = "pending"

            try Self.changeTitleInASecondContext(of: container)
            let refetched = try Self.fetchRow(held.persistentModelID, in: longLived)
            #expect(refetched.title == "seeded")
            try longLived.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "seeded", notes: "pending"))
        }
    }

    @Test(
        "Characterises SwiftData: a rollback lets the next fetch refresh the row",
        arguments: StoreLocation.allCases
    )
    func characterisesARollbackBeforeTheFetch(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let longLived = ModelContext(container)
            let held = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            held.notes = "pending"

            try Self.changeTitleInASecondContext(of: container)
            longLived.rollback()
            let refetched = try Self.fetchRow(held.persistentModelID, in: longLived)
            #expect(refetched.title == "second")
            #expect(refetched.notes == "seeded")
            refetched.notes = "after rollback"
            try longLived.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "second", notes: "after rollback"))
        }
    }

    @Test(
        "Characterises SwiftData: a fresh context's fetch and save keeps a second context's change",
        arguments: StoreLocation.allCases
    )
    func characterisesAFreshContextsFetchAndSave(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            try Self.changeTitleInASecondContext(of: container)

            let fresh = ModelContext(container)
            let row = try #require(fresh.fetch(FetchDescriptor<StaleSaveRow>()).first)
            row.notes = "fresh"
            try fresh.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "second", notes: "fresh"))
        }
    }

    /// `deleteAllData` runs first because SQLite logs a client bug when an open store is unlinked.
    private static func withSeededContainer(
        at location: StoreLocation,
        _ body: (ModelContainer) throws -> Void
    ) throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try makeSeededContainer(at: location, in: directory)
        defer { container.deleteAllData() }
        try body(container)
    }

    private static func makeSeededContainer(at location: StoreLocation, in directory: URL) throws -> ModelContainer {
        let schema = Schema([StaleSaveRow.self])
        let configuration = switch location {
        case .inMemory:
            CharacterisationStore.inMemoryConfiguration(schema: schema)
        case .onDisk:
            CharacterisationStore.onDiskConfiguration(named: "stale", schema: schema, in: directory)
        }
        let container = try ModelContainer(for: schema, configurations: configuration)
        let seeding = ModelContext(container)
        seeding.insert(StaleSaveRow())
        try seeding.save()
        return container
    }

    private static func changeTitleInASecondContext(of container: ModelContainer) throws {
        let second = ModelContext(container)
        let row = try #require(second.fetch(FetchDescriptor<StaleSaveRow>()).first)
        row.title = "second"
        try second.save()
    }

    private static func fetchRow(
        _ identifier: PersistentIdentifier,
        in context: ModelContext
    ) throws -> StaleSaveRow {
        let descriptor = FetchDescriptor<StaleSaveRow>(
            predicate: #Predicate { $0.persistentModelID == identifier }
        )
        return try #require(context.fetch(descriptor).first)
    }

    private static func savedValues(in container: ModelContainer) throws -> RowValues {
        let reader = ModelContext(container)
        return try withExtendedLifetime(reader) {
            let row = try #require(reader.fetch(FetchDescriptor<StaleSaveRow>()).first)
            return RowValues(title: row.title, notes: row.notes)
        }
    }

}
