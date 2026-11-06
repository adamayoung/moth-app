//  PostmanImportNamingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
@testable import MothImport
import Testing

struct PostmanImportNamingTests {

    private static let collectionPath = "postman-code-generators/basicCollection.json"
    private static let environmentPath = "newman/env.json"

    private static func name(
        of path: String,
        existingCollections: Set<String> = [],
        existingEnvironments: Set<String> = []
    ) async throws -> String {
        try await PostmanImporter(secretStore: InMemorySecretStore()).importFile(
            Fixture.data(path),
            existingCollectionNames: existingCollections,
            existingEnvironmentNames: existingEnvironments
        ).name
    }

    @Test(
        "A collection whose name is taken gets the first free suffix",
        arguments: [
            ([], "Basic Collection"),
            (["Basic Collection"], "Basic Collection 2"),
            (["Basic Collection", "Basic Collection 2"], "Basic Collection 3"),
            (["Basic Collection", "Basic Collection 3"], "Basic Collection 2"),
            (["basic collection"], "Basic Collection")
        ] as [(Set<String>, String)]
    )
    func suffixesCollection(existing: Set<String>, expected: String) async throws {
        #expect(try await Self.name(of: Self.collectionPath, existingCollections: existing) == expected)
    }

    @Test("An environment whose name is taken gets the first free suffix")
    func suffixesEnvironment() async throws {
        #expect(try await Self.name(of: Self.environmentPath, existingEnvironments: ["envTest"]) == "envTest 2")
        #expect(
            try await Self.name(of: Self.environmentPath, existingEnvironments: ["envTest", "envTest 2"])
                == "envTest 3"
        )
    }

    @Test("A collection and an environment can share a name")
    func checksNamesPerKind() async throws {
        #expect(
            try await Self.name(of: Self.collectionPath, existingEnvironments: ["Basic Collection"])
                == "Basic Collection"
        )
        #expect(try await Self.name(of: Self.environmentPath, existingCollections: ["envTest"]) == "envTest")
    }

    @Test("A folder or request with no name is Untitled, from a snippet because exports always name them")
    func namesMissingItems() async throws {
        let result = try await Fixture.importingSnippet(items: #"""
        [
            { "item": [] },
            { "name": " ", "item": [] },
            { "request": {} },
            { "name": "", "request": {} }
        ]
        """#)
        let children = try #require(result.collection?.children)

        #expect(children.compactMap(\.folder).map(\.name) == ["Untitled", "Untitled"])
        #expect(children.compactMap(\.request).map(\.name) == ["Untitled", "Untitled"])
    }

    @Test("An environment with no name is Untitled, and takes a suffix like any other")
    func namesMissingEnvironment() async throws {
        let result = try await PostmanImporter(secretStore: InMemorySecretStore()).importFile(
            Data(#"{ "_postman_variable_scope": "environment", "values": [] }"#.utf8),
            existingCollectionNames: [],
            existingEnvironmentNames: ["Untitled"]
        )

        #expect(result.name == "Untitled 2")
    }

}
