//  PostmanImportStoreTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import SwiftData
import Testing

struct PostmanImportStoreTests {

    @Test("An import hands its content to the store, and a writer keeps the whole tree")
    func writesTheWholeTree() async throws {
        let dataModel = try DataModel.inMemory()
        let writer = dataModel.writer

        let result = try await PostmanImporter(secretStore: InMemorySecretStore()).importFile(
            Fixture.data("postman-collection-transformer/v2.1.0/nestedEntities.json"),
            existingCollectionNames: [],
            existingEnvironmentNames: [],
            into: { try await writer.create($0) }
        )

        let context = ModelContext(dataModel.container)
        let row = try #require(context.fetch(FetchDescriptor<CollectionModel>()).first)
        #expect(try row.asDomain() == result.collection)
    }

    @Test("A store that refuses the rows leaves none of the import's secrets saved")
    func refusedRowsRemoveTheSecrets() async throws {
        let secretStore = RecordingSecretStore()
        let data = try Fixture.data("postman-collection-transformer/v2.1.0/nestedEntities.json")

        await #expect(throws: StoreRefusal.self) {
            try await PostmanImporter(secretStore: secretStore).importFile(
                data,
                existingCollectionNames: [],
                existingEnvironmentNames: [],
                into: { _ in throw StoreRefusal() }
            )
        }

        #expect(await secretStore.values.isEmpty)
    }

    @Test("A secret that won't save stops the import before the store, from a snippet for a known credential")
    func refusedSecretNeverReachesTheStore() async throws {
        let data = Fixture.snippetCollection(items: #"""
        [{
            "name": "a",
            "request": { "auth": { "type": "bearer", "bearer": [{ "key": "token", "value": "refused" }] } }
        }]
        """#)

        await #expect(throws: RecordingSecretStore.Failure.refused) {
            try await PostmanImporter(secretStore: RecordingSecretStore(refusing: "refused")).importFile(
                data,
                existingCollectionNames: [],
                existingEnvironmentNames: [],
                into: { _ in Issue.record("The store was reached") }
            )
        }
    }

    private struct StoreRefusal: Error {}

}
