//  PostmanImportRejectionTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
@testable import MothImport
import Testing

struct PostmanImportRejectionTests {

    private static func importing(_ data: Data) async throws -> PostmanImportResult {
        try await PostmanImporter(secretStore: InMemorySecretStore()).importFile(
            data,
            existingCollectionNames: [],
            existingEnvironmentNames: []
        )
    }

    @Test(
        "A file that isn't a v2.1 collection or an environment is refused",
        arguments: [
            "postman-collection-transformer/v1.0.0/binary-upload.json",
            "postman-collection-transformer/v2.1.0/proper-description-parsing.json"
        ]
    )
    func refusesOtherPostmanFiles(path: String) async throws {
        let data = try Fixture.data(path)

        await #expect(throws: PostmanImportError.unrecognisedFile) {
            try await Self.importing(data)
        }
    }

    @Test("A globals export has an environment's shape and is refused, from a snippet as no licensed fixture has one")
    func refusesGlobals() async {
        let data = Data(#"""
        { "name": "Globals", "values": [], "_postman_variable_scope": "globals" }
        """#.utf8)

        await #expect(throws: PostmanImportError.unrecognisedFile) {
            try await Self.importing(data)
        }
    }

    @Test("JSON with neither a name nor a scope isn't an environment, from a snippet as no licensed fixture lacks both")
    func refusesAValuesArrayAlone() async {
        await #expect(throws: PostmanImportError.unrecognisedFile) {
            try await Self.importing(Data(#"{ "values": [] }"#.utf8))
        }
    }

    @Test("A file that isn't JSON is refused")
    func refusesNonJSON() async {
        await #expect(throws: PostmanImportError.unrecognisedFile) {
            try await Self.importing(Data("not json".utf8))
        }
    }

}
