//  PostmanImportRejectionTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import MothImport
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

    @Test("A file that isn't JSON is refused")
    func refusesNonJSON() async {
        await #expect(throws: PostmanImportError.unrecognisedFile) {
            try await Self.importing(Data("not json".utf8))
        }
    }

}
