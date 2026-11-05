//  MothImportWiringTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct MothImportWiringTests {

    @Test("Wiring: PostmanImporter takes MothCore's secret store and asks PostmanKit's schema")
    func reachesBothDependencies() {
        let importer = PostmanImporter(secretStore: InMemorySecretStore())

        #expect(importer.canImport(schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"))
        #expect(!importer.canImport(schema: "https://schema.getpostman.com/json/collection/v2.0.0/collection.json"))
    }

}
