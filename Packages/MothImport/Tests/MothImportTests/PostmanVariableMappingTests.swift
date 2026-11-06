//  PostmanVariableMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanVariableMappingTests {

    private static let nested = "postman-collection-transformer/v2.1.0/nestedEntities.json"

    private static func variableTypeSnippet(_ variables: String) async throws -> [Variable] {
        let result = try await Fixture.importingSnippet(items: "[]", extraKeys: #""variable": \#(variables),"#)
        return try #require(result.collection?.variables)
    }

    @Test("Collection variables map with the value as both initial and current")
    func mapsCollectionVariables() async throws {
        let collection = try await Fixture.collection(Self.nested)

        let variable = try #require(collection.variables.first)

        #expect(collection.variables.count == 1)
        #expect(variable.name == "collection")
        #expect(variable.value == .plain(initial: "variable", current: "variable"))
        #expect(variable.isEnabled)
    }

    @Test("Request variables map")
    func mapsRequestVariables() async throws {
        let collection = try await Fixture.collection(Self.nested)

        let variables = try collection.request(named: "Basic").variables

        #expect(variables.map(\.name) == ["request"])
        #expect(variables.map(\.initialValue) == ["variable"])
    }

    @Test("Folder variables have nowhere to go, so they're counted")
    func countsFolderVariables() async throws {
        let result = try await Fixture.importing(Self.nested)

        #expect(result.skipped.folderVariables == 1)
    }

    @Test("A disabled variable stays disabled")
    func keepsDisabledVariable() async throws {
        let variables = try await Self.variableTypeSnippet(#"[{ "key": "a", "value": "b", "disabled": true }]"#)

        #expect(variables.map(\.isEnabled) == [false])
    }

    @Test("A variable named only by its id takes that as its name")
    func usesIDAsName() async throws {
        let variables = try await Self.variableTypeSnippet(#"[{ "id": "a", "value": "b" }]"#)

        #expect(variables.map(\.name) == ["a"])
    }

    @Test("Numbers, booleans and a missing value become text")
    func convertsValuesToText() async throws {
        let variables = try await Self.variableTypeSnippet(#"""
        [
            { "key": "whole", "value": 1 },
            { "key": "fraction", "value": 1.5 },
            { "key": "flag", "value": true },
            { "key": "nothing", "value": null },
            { "key": "absent" },
            { "key": "list", "value": [1, "a"] }
        ]
        """#)

        #expect(variables.map(\.initialValue) == ["1", "1.5", "true", "", "", #"[1,"a"]"#])
    }

    @Test("A secret collection variable goes to the secret store, from a snippet as no licensed fixture has one")
    func storesSecretCollectionVariable() async throws {
        let store = InMemorySecretStore()
        let result = try await Fixture.importingSnippet(
            items: "[]",
            extraKeys: #""variable": [{ "key": "a", "value": "hidden", "type": "secret" }],"#,
            secretStore: store
        )

        let variable = try #require(result.collection?.variables.first)
        let reference = try #require(variable.secretReference)

        #expect(await store.value(for: reference.identifier) == "hidden")
        #expect(result.secrets == [reference])
    }

    @Test("A secret the file holds no value for has a reference and saves nothing")
    func secretWithNoValueSavesNothing() async throws {
        let result = try await Fixture.importingSnippet(
            items: "[]",
            extraKeys: #""variable": [{ "key": "a", "type": "secret" }],"#
        )

        let variable = try #require(result.collection?.variables.first)

        #expect(variable.isSecret)
        #expect(result.secrets.isEmpty)
    }

    @Test("A secret left empty saves nothing, so Moth reports it as missing instead of sending it blank")
    func emptySecretSavesNothing() async throws {
        let result = try await Fixture.importingSnippet(
            items: "[]",
            extraKeys: #""variable": [{ "key": "a", "value": "", "type": "secret" }],"#
        )

        let variable = try #require(result.collection?.variables.first)

        #expect(variable.isSecret)
        #expect(result.secrets.isEmpty)
    }

}
