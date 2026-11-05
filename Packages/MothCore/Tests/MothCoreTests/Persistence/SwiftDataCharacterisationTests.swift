//  SwiftDataCharacterisationTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData
import Testing

@Model
final class CrossStoreOwner {
    var name: String = ""

    @Relationship(deleteRule: .nullify, inverse: \CrossStoreItem.owner)
    var items: [CrossStoreItem]? = []

    init(name: String) {
        self.name = name
    }
}

@Model
final class CrossStoreItem {
    var label: String = ""
    var owner: CrossStoreOwner?

    init(label: String) {
        self.label = label
    }
}

@Model
final class StoreRoutingControl {
    var label: String = ""

    init(label: String) {
        self.label = label
    }
}

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

enum StoreLocation: CaseIterable {
    case inMemory
    case onDisk
}

struct SwiftDataCharacterisationTests {

    private nonisolated static let ownersConfiguration = "owners"
    private nonisolated static let itemsConfiguration = "items"

    @Test("Characterises SwiftData: control, an unrelated model lands in its own configuration's store")
    func characterisesAnUnrelatedModelStayingInItsStore() throws {
        let container = try ModelContainer(
            for: Schema([CrossStoreOwner.self, CrossStoreItem.self, StoreRoutingControl.self]),
            configurations: [
                Self.inMemoryConfiguration(named: "related", for: [CrossStoreOwner.self]),
                Self.inMemoryConfiguration(named: "unrelated", for: [StoreRoutingControl.self])
            ]
        )
        let context = ModelContext(container)
        let owner = CrossStoreOwner(name: "owner")
        let control = StoreRoutingControl(label: "control")
        context.insert(owner)
        context.insert(control)
        try context.save()

        let relatedStore = container.storeIdentifier(forConfigurationNamed: "related")
        let unrelatedStore = container.storeIdentifier(forConfigurationNamed: "unrelated")
        #expect(relatedStore != unrelatedStore)
        #expect(owner.persistentModelID.storeIdentifier == relatedStore)
        #expect(control.persistentModelID.storeIdentifier == unrelatedStore)
    }

    @Test(
        "Characterises SwiftData: related models in two in-memory configurations both land in one store",
        arguments: [
            [ownersConfiguration, itemsConfiguration],
            [itemsConfiguration, ownersConfiguration]
        ]
    )
    func characterisesRelatedModelsLandingInOneStore(configurationNames: [String]) throws {
        let configurations = configurationNames.map { name in
            name == Self.ownersConfiguration
                ? Self.inMemoryConfiguration(named: name, for: [CrossStoreOwner.self])
                : Self.inMemoryConfiguration(named: name, for: [CrossStoreItem.self])
        }
        let container = try ModelContainer(
            for: Schema([CrossStoreOwner.self, CrossStoreItem.self]),
            configurations: configurations
        )
        let writer = ModelContext(container)
        let owner = CrossStoreOwner(name: "owner")
        let item = CrossStoreItem(label: "item")
        writer.insert(owner)
        writer.insert(item)
        item.owner = owner
        try writer.save()

        #expect(owner.persistentModelID.storeIdentifier == item.persistentModelID.storeIdentifier)
        for configuration in configurations {
            let entities = configuration.schema?.entities.map(\.name).sorted()
            #expect(entities == ["CrossStoreItem", "CrossStoreOwner"])
        }
        let readBack = try #require(ModelContext(container).fetch(FetchDescriptor<CrossStoreItem>()).first)
        #expect(readBack.owner?.name == "owner")
    }

    @Test("Characterises SwiftData: relating rows already in two stores traps at the assignment")
    func characterisesARelationshipBetweenRowsInTwoStores() async throws {
        let directory = try Self.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await #expect(
            processExitsWith: .failure,
            observing: [\.standardErrorContent]
        ) { [directory = directory as URL] in
            try await SwiftDataCharacterisationTests.relateRowsInTwoStores(in: directory)
        }

        let standardError = try String(decoding: #require(result).standardErrorContent, as: UTF8.self)
        #expect(standardError.contains("Illegal attempt to relate"))
        #expect(standardError.contains("to a model in another store"))
    }

    @Test(
        "Characterises SwiftData: a stale save of the property a second context changed",
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
        "Characterises SwiftData: a stale save of a different property of the row a second context changed",
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
        "Characterises SwiftData: a long-lived context's re-fetch sees a second context's save",
        arguments: StoreLocation.allCases
    )
    func characterisesARefetchInALongLivedContext(location: StoreLocation) throws {
        try Self.withSeededContainer(at: location) { container in
            let longLived = ModelContext(container)
            let held = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(held.title == "seeded")

            try Self.changeTitleInASecondContext(of: container)
            let refetched = try #require(longLived.fetch(FetchDescriptor<StaleSaveRow>()).first)
            #expect(refetched.title == "second")
            refetched.notes = "long-lived"
            try longLived.save()

            let saved = try Self.savedValues(in: container)
            #expect(saved == RowValues(title: "second", notes: "long-lived"))
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

    static func relateRowsInTwoStores(in directory: URL) throws {
        let schema = Schema([CrossStoreOwner.self, CrossStoreItem.self])
        let owners = onDiskConfiguration(named: ownersConfiguration, schema: schema, in: directory)
        let items = onDiskConfiguration(named: itemsConfiguration, schema: schema, in: directory)
        try seed(CrossStoreOwner(name: "owner"), in: owners, schema: schema)
        try seed(CrossStoreItem(label: "item"), in: items, schema: schema)

        let container = try ModelContainer(for: schema, configurations: [owners, items])
        let context = ModelContext(container)
        let owner = try #require(context.fetch(FetchDescriptor<CrossStoreOwner>()).first)
        let item = try #require(context.fetch(FetchDescriptor<CrossStoreItem>()).first)
        try #require(owner.persistentModelID.storeIdentifier != item.persistentModelID.storeIdentifier)

        item.owner = owner
    }

    /// `.automatic`, the default, uses CloudKit when the test host has the entitlement.
    private static func inMemoryConfiguration(
        named name: String,
        for types: [any PersistentModel.Type]
    ) -> ModelConfiguration {
        ModelConfiguration(name, schema: Schema(types), isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    }

    private static func onDiskConfiguration(
        named name: String,
        schema: Schema,
        in directory: URL
    ) -> ModelConfiguration {
        ModelConfiguration(
            name,
            schema: schema,
            url: directory.appending(path: "\(name).store"),
            cloudKitDatabase: .none
        )
    }

    private static func seed(
        _ row: some PersistentModel,
        in configuration: ModelConfiguration,
        schema: Schema
    ) throws {
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)
        context.insert(row)
        try context.save()
    }

    /// `deleteAllData` runs first because SQLite logs a client bug when an open store is unlinked.
    private static func withSeededContainer(
        at location: StoreLocation,
        _ body: (ModelContainer) throws -> Void
    ) throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try makeSeededContainer(at: location, in: directory)
        defer { container.deleteAllData() }
        try body(container)
    }

    private static func makeSeededContainer(at location: StoreLocation, in directory: URL) throws -> ModelContainer {
        let schema = Schema([StaleSaveRow.self])
        let configuration = switch location {
        case .inMemory:
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .onDisk:
            onDiskConfiguration(named: "stale", schema: schema, in: directory)
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

    private static func savedValues(in container: ModelContainer) throws -> RowValues {
        let row = try #require(ModelContext(container).fetch(FetchDescriptor<StaleSaveRow>()).first)
        return RowValues(title: row.title, notes: row.notes)
    }

    private static func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "SwiftDataCharacterisationTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

}
