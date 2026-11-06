//  PostmanImportSummaryTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
@testable import MothImport
import Testing

struct PostmanImportSummaryTests {

    @Test("A collection names both its counts, and what the import skipped")
    func summarisesACollection() async throws {
        let result = try await Fixture.importing("postman-collection-transformer/v2.1.0/nestedEntities.json")

        #expect(result.importedSummary == "Imported \u{201C}auth-v1\u{201D}: 2 requests, 1 folder.")
        #expect(result.skippedSummary == "Skipped 8 scripts, 1 folder variable, 5 descriptions and 1 OAuth 1.0 auth.")
    }

    @Test("A collection with nothing skipped says nothing about skipping")
    func saysNothingWhenNothingIsSkipped() async throws {
        let result = try await Fixture.importing("postman-code-generators/formdataCollection.json")

        #expect(result.importedSummary == "Imported \u{201C}Multipart/form-data\u{201D}: 1 request, 0 folders.")
        #expect(result.skippedSummary == nil)
    }

    @Test("An environment names its variables")
    func summarisesAnEnvironment() async throws {
        let result = try await Fixture.importing("postman-cli-action/postman-echo-environment.json")

        #expect(result.importedSummary == "Imported \u{201C}Postman Echo Environment\u{201D}: 4 variables.")
        #expect(result.skippedSummary == nil)
    }

    @Test("An environment of one variable reads in the singular, from a snippet as no licensed fixture has one")
    func summarisesOneVariable() async throws {
        let data = Data(#"{ "name": "One", "values": [{ "key": "a", "value": "b" }] }"#.utf8)

        let result = try await PostmanImporter(secretStore: InMemorySecretStore()).importFile(
            data,
            existingCollectionNames: [],
            existingEnvironmentNames: []
        )

        #expect(result.importedSummary == "Imported \u{201C}One\u{201D}: 1 variable.")
    }

    @Test("Two skipped kinds join with “and” alone")
    func joinsTwoKinds() {
        var skipped = PostmanSkippedCounts()
        skipped.scripts = 4
        skipped.auth = [.oauth1: 1]

        #expect(skipped.summary == "Skipped 4 scripts and 1 OAuth 1.0 auth.")
    }

    @Test(
        "Each skipped kind reads correctly at one and at more than one",
        arguments: [
            (Self.counts(\.scripts, 1), "Skipped 1 script."),
            (Self.counts(\.scripts, 2), "Skipped 2 scripts."),
            (Self.counts(\.folderVariables, 1), "Skipped 1 folder variable."),
            (Self.counts(\.folderVariables, 2), "Skipped 2 folder variables."),
            (Self.counts(\.descriptions, 1), "Skipped 1 description."),
            (Self.counts(\.descriptions, 2), "Skipped 2 descriptions."),
            (Self.counts(\.bodies, 1), "Skipped 1 request body."),
            (Self.counts(\.bodies, 2), "Skipped 2 request bodies."),
            (Self.counts(\.exampleResponses, 1), "Skipped 1 example response."),
            (Self.counts(\.exampleResponses, 2), "Skipped 2 example responses.")
        ]
    )
    func readsEachKind(skipped: PostmanSkippedCounts, expected: String) {
        #expect(skipped.summary == expected)
    }

    @Test(
        "An auth is named by its kind, and an unknown kind by the file's own word",
        arguments: [
            (PostmanAuthKind.oauth1, 1, "Skipped 1 OAuth 1.0 auth."),
            (PostmanAuthKind.oauth1, 2, "Skipped 2 OAuth 1.0 auths."),
            (PostmanAuthKind.hawk, 1, "Skipped 1 Hawk auth."),
            (PostmanAuthKind.ntlm, 1, "Skipped 1 NTLM auth."),
            (PostmanAuthKind.edgeGrid, 1, "Skipped 1 EdgeGrid auth."),
            (PostmanAuthKind.other("custom"), 3, "Skipped 3 custom auths.")
        ]
    )
    func namesEachAuthKind(kind: PostmanAuthKind, count: Int, expected: String) {
        var skipped = PostmanSkippedCounts()
        skipped.auth = [kind: count]

        #expect(skipped.summary == expected)
    }

    @Test("Auth kinds list in a fixed order, because a dictionary has none")
    func listsAuthKindsInOrder() {
        var skipped = PostmanSkippedCounts()
        skipped.auth = [.oauth1: 1, .hawk: 2]

        #expect(skipped.summary == "Skipped 2 Hawk auths and 1 OAuth 1.0 auth.")
    }

    private nonisolated static func counts(
        _ kind: WritableKeyPath<PostmanSkippedCounts, Int>,
        _ count: Int
    ) -> PostmanSkippedCounts {
        var skipped = PostmanSkippedCounts()
        skipped[keyPath: kind] = count
        return skipped
    }

}
