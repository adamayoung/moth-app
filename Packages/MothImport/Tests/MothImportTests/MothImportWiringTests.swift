//  MothImportWiringTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct MothImportWiringTests {

    @Test("Wiring: PostmanImporter reaches MothCore's secret store and PostmanKit's schema")
    func reachesBothDependencies() throws {
        let store = InMemorySecretStore()
        store.save("s3cret", for: "api-key")

        let importer = PostmanImporter(secretStore: store)

        #expect(try importer.secretStore.value(for: "api-key") == "s3cret")
        #expect(importer.canImport(schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"))
        #expect(!importer.canImport(schema: "https://schema.getpostman.com/json/collection/v2.0.0/collection.json"))
    }

}
