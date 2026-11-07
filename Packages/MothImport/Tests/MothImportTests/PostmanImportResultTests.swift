//  PostmanImportResultTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanImportResultTests {

    @Test("The result reports what a nested collection imported and skipped")
    func reportsNestedCollection() async throws {
        let result = try await Fixture.importing("postman-collection-transformer/v2.1.0/nestedEntities.json")

        #expect(result.name == "auth-v1")
        #expect(result.imported.folders == 1)
        #expect(result.imported.requests == 2)
        #expect(result.imported.variables == 3)
        #expect(result.imported.unsupportedAuth.isEmpty)
        #expect(result.skipped.scripts == 8)
        #expect(result.skipped.folderVariables == 1)
        #expect(result.skipped.descriptions == 5)
        #expect(result.skipped.bodies == 0)
        #expect(result.skipped.auth == [.oauth1: 1])
        #expect(result.secrets.count == 3)
    }

    @Test("The result tells auth stored but unsupported from auth dropped")
    func reportsEachAuthOutcome() async throws {
        let result = try await Fixture.importing("postman-collection-transformer/v2.1.0/helpers.json")

        #expect(result.imported.requests == 5)
        #expect(result.imported.unsupportedAuth == [.oauth2: 1])
        #expect(result.skipped.auth == [.oauth1: 1])
        #expect(result.skipped.scripts == 2)
        #expect(result.secrets.count == 7)
    }

    @Test("Scripts with no code aren't counted, at the collection level or on a request")
    func leavesBlankScriptsUncounted() async throws {
        let result = try await Fixture.importing("postman-code-generators/basicCollection.json")

        #expect(result.skipped.scripts == 4)
    }

    @Test(
        "Each description is counted once, on a request whichever of its two places holds it",
        arguments: [
            ("postman-code-generators/basicCollection.json", 14),
            ("openapi-to-postman/collection.json", 3),
            ("openapi-to-postman/internalRefsCollection.json", 6)
        ]
    )
    func countsDescriptions(path: String, expected: Int) async throws {
        let result = try await Fixture.importing(path)

        #expect(result.skipped.descriptions == expected)
    }

    @Test(
        "Saved example responses have nowhere to go, so they're counted",
        arguments: [
            ("openapi-to-postman/collection.json", 6),
            ("openapi-to-postman/internalRefsCollection.json", 3),
            ("postman-code-generators/unsupportedMethods.json", 1)
        ]
    )
    func countsExampleResponses(path: String, expected: Int) async throws {
        let result = try await Fixture.importing(path)

        #expect(result.skipped.exampleResponses == expected)
    }

    @Test("The result reports an environment's name and variables")
    func reportsEnvironment() async throws {
        let result = try await Fixture.importing("postman-cli-action/postman-echo-environment.json")

        #expect(result.name == "Postman Echo Environment")
        #expect(result.imported.variables == 4)
        #expect(result.imported.folders == 0)
        #expect(result.imported.requests == 0)
        #expect(result.skipped.scripts == 0)
        #expect(result.skipped.descriptions == 0)
        #expect(result.secrets.isEmpty)
    }

}
