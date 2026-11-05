//  SwiftDataCrossStoreCharacterisationTests.swift
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

struct SwiftDataCrossStoreCharacterisationTests {

    private static let ownersConfiguration = "owners"
    private static let itemsConfiguration = "items"

    @Test("Characterises SwiftData: control, an unrelated model lands in its own configuration's store")
    func characterisesAnUnrelatedModelStayingInItsStore() throws {
        let container = try ModelContainer(
            for: Schema([CrossStoreOwner.self, CrossStoreItem.self, StoreRoutingControl.self]),
            configurations: [
                CharacterisationStore.inMemoryConfiguration(named: "related", schema: Schema([CrossStoreOwner.self])),
                CharacterisationStore.inMemoryConfiguration(
                    named: "unrelated",
                    schema: Schema([StoreRoutingControl.self])
                )
            ]
        )
        let context = ModelContext(container)
        let owner = CrossStoreOwner(name: "owner")
        let control = StoreRoutingControl(label: "control")
        context.insert(owner)
        context.insert(control)
        try context.save()

        let relatedStore = try #require(container.storeIdentifier(forConfigurationNamed: "related"))
        let unrelatedStore = try #require(container.storeIdentifier(forConfigurationNamed: "unrelated"))
        #expect(relatedStore != unrelatedStore)
        #expect(owner.persistentModelID.storeIdentifier == relatedStore)
        #expect(control.persistentModelID.storeIdentifier == unrelatedStore)
    }

    @Test(
        "Characterises SwiftData: related models in two configurations both land in one store",
        arguments: StoreLocation.allCases
    )
    func characterisesRelatedModelsLandingInOneStore(location: StoreLocation) throws {
        let directory = try CharacterisationStore.makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (container, configurations) = try Self.makeRelatedModelContainer(at: location, in: directory)
        defer { container.deleteAllData() }

        let writer = ModelContext(container)
        let owner = CrossStoreOwner(name: "owner")
        let item = CrossStoreItem(label: "item")
        writer.insert(owner)
        writer.insert(item)
        item.owner = owner
        try writer.save()

        let ownerStore = try #require(owner.persistentModelID.storeIdentifier)
        let itemStore = try #require(item.persistentModelID.storeIdentifier)
        #expect(ownerStore == itemStore)
        for configuration in configurations {
            let entities = configuration.schema?.entities.map(\.name).sorted()
            #expect(entities == ["CrossStoreItem", "CrossStoreOwner"])
        }
        let reader = ModelContext(container)
        try withExtendedLifetime(reader) {
            let readBack = try #require(reader.fetch(FetchDescriptor<CrossStoreItem>()).first)
            #expect(readBack.owner?.name == "owner")
        }
    }

    #if os(macOS)
        @Test("Characterises SwiftData: relating rows already in two stores traps at the assignment")
        func characterisesARelationshipBetweenRowsInTwoStores() async throws {
            let directory = try CharacterisationStore.makeTemporaryDirectory()
            defer { try? FileManager.default.removeItem(at: directory) }

            let result = await #expect(
                processExitsWith: .failure,
                observing: [\.standardErrorContent]
            ) { [directory = directory as URL] in
                try await SwiftDataCrossStoreCharacterisationTests.relateRowsInTwoStores(in: directory)
            }

            let exit = try #require(result)
            let standardError = try #require(String(bytes: exit.standardErrorContent, encoding: .utf8))
            #expect(standardError.contains("Illegal attempt to relate"))
            #expect(standardError.contains("to a model in another store"))
        }

        static func relateRowsInTwoStores(in directory: URL) throws {
            let schema = Schema([CrossStoreOwner.self, CrossStoreItem.self])
            let owners = CharacterisationStore.onDiskConfiguration(
                named: ownersConfiguration,
                schema: schema,
                in: directory
            )
            let items = CharacterisationStore.onDiskConfiguration(
                named: itemsConfiguration,
                schema: schema,
                in: directory
            )
            try seed(CrossStoreOwner(name: "owner"), in: owners, schema: schema)
            try seed(CrossStoreItem(label: "item"), in: items, schema: schema)

            let container = try ModelContainer(for: schema, configurations: [owners, items])
            let context = ModelContext(container)
            let owner = try #require(context.fetch(FetchDescriptor<CrossStoreOwner>()).first)
            let item = try #require(context.fetch(FetchDescriptor<CrossStoreItem>()).first)
            let ownerStore = try #require(owner.persistentModelID.storeIdentifier)
            let itemStore = try #require(item.persistentModelID.storeIdentifier)
            try #require(ownerStore != itemStore)

            item.owner = owner
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
    #endif

    private static func makeRelatedModelContainer(
        at location: StoreLocation,
        in directory: URL
    ) throws -> (ModelContainer, [ModelConfiguration]) {
        let ownersSchema = Schema([CrossStoreOwner.self])
        let itemsSchema = Schema([CrossStoreItem.self])
        let configurations = switch location {
        case .inMemory:
            [
                CharacterisationStore.inMemoryConfiguration(named: ownersConfiguration, schema: ownersSchema),
                CharacterisationStore.inMemoryConfiguration(named: itemsConfiguration, schema: itemsSchema)
            ]
        case .onDisk:
            [
                CharacterisationStore.onDiskConfiguration(
                    named: ownersConfiguration,
                    schema: ownersSchema,
                    in: directory
                ),
                CharacterisationStore.onDiskConfiguration(
                    named: itemsConfiguration,
                    schema: itemsSchema,
                    in: directory
                )
            ]
        }
        let container = try ModelContainer(
            for: Schema([CrossStoreOwner.self, CrossStoreItem.self]),
            configurations: configurations
        )
        return (container, configurations)
    }

}
