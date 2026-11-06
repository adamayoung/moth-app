//  PostmanEnvironmentImportTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
@testable import MothImport
import Testing

struct PostmanEnvironmentImportTests {

    private static func environment(_ path: String) async throws -> WorkspaceEnvironment {
        try #require(await Fixture.importing(path).environment)
    }

    @Test("An environment keeps its name, values and order")
    func mapsNameAndValues() async throws {
        let environment = try await Self.environment("postman-cli-action/postman-echo-environment.json")

        #expect(environment.name == "Postman Echo Environment")
        #expect(environment.variables.map(\.name) == ["baseUrl", "userName", "environmentName", "testParam"])
        #expect(environment.variables.map(\.initialValue) == [
            "https://postman-echo.com", "Postman CLI Action", "ci", "hello-world"
        ])
        #expect(environment.variables.map(\.currentValue) == environment.variables.map(\.initialValue))
        #expect(environment.variables.allSatisfy { !$0.isSecret })
    }

    @Test("A variable an app export marks enabled: false stays disabled")
    func keepsEnabledFalse() async throws {
        let environment = try await Self.environment("newman/env.json")

        #expect(environment.variables.map(\.name) == ["dummyVar"])
        #expect(environment.variables.map(\.isEnabled) == [false])
    }

    @Test("Disabled variables and duplicates keep their flags and order")
    func keepsDisabledAndDuplicates() async throws {
        let environment = try await Self.environment("newman/disabled-and-duplicates.postman_environment.json")

        #expect(environment.variables.map(\.name) == [
            "justDisabled", "oneDisabled", "oneDisabled", "duplicate", "duplicate"
        ])
        #expect(environment.variables.map(\.initialValue) == ["1", "1", "2", "1", "2"])
        #expect(environment.variables.map(\.isEnabled) == [false, true, false, true, true])
    }

    @Test("A file that starts with a byte order mark imports")
    func importsFileWithByteOrderMark() async throws {
        let environment = try await Self.environment("newman/bom-in-environment-file.postman_environment.json")

        #expect(environment.name == "Variable names with slashes")
        #expect(environment.variables.count == 2)
    }

    @Test("A secret variable goes to the secret store, from a snippet because no licensed fixture has one")
    func storesSecretVariable() async throws {
        let store = InMemorySecretStore()
        let data = Data(#"""
        { "name": "Env", "values": [{ "key": "token", "value": "hidden", "type": "secret", "enabled": true }] }
        """#.utf8)

        let result = try await PostmanImporter(secretStore: store).importFile(
            data,
            existingCollectionNames: [],
            existingEnvironmentNames: []
        )

        let variable = try #require(result.environment?.variables.first)
        let reference = try #require(variable.secretReference)

        #expect(variable.name == "token")
        #expect(await store.value(for: reference.identifier) == "hidden")
        #expect(result.secrets == [reference])
    }

}
