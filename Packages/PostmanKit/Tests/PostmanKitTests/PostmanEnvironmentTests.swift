//  PostmanEnvironmentTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit
import Testing

struct PostmanEnvironmentTests {

    @Test("An app export decodes its name, values, types and enabled flags")
    func decodesAppExport() throws {
        let environment = try Fixture.environment("newman/slashed-variable-names.postman_environment.json")

        #expect(environment.id == "043ddbc2-1fbb-242f-9c39-dc89e08d4a65")
        #expect(environment.name == "Variable names with slashes")
        #expect(environment.values.map(\.key) == ["fo/o", "b\\ar"])
        #expect(environment.values.map(\.value) == [.string("alpha"), .string("beta")])
        #expect(environment.values.map(\.type) == ["text", "text"])
        #expect(environment.values.map(\.isEnabled) == [true, true])
    }

    @Test("A value an app export marks enabled: false stays off")
    func appExportKeepsEnabledFalse() throws {
        let environment = try Fixture.environment("newman/env.json")

        let value = try #require(environment.values.only)

        #expect(value.key == "dummyVar")
        #expect(value.value == .string("bar"))
        #expect(!value.isEnabled)
    }

    @Test("A value marked disabled: true stays off, and duplicates keep their order")
    func keepsDisabledAndDuplicates() throws {
        let environment = try Fixture.environment("newman/disabled-and-duplicates.postman_environment.json")

        #expect(environment.values.map(\.key) == [
            "justDisabled",
            "oneDisabled",
            "oneDisabled",
            "duplicate",
            "duplicate"
        ])
        #expect(environment.values.map(\.value) == ["1", "1", "2", "1", "2"].map(PostmanValue.string))
        #expect(environment.values.map(\.isEnabled) == [false, true, false, true, true])
        #expect(environment.values.map(\.type) == [nil, nil, nil, "text", "text"])
    }

    @Test("A value of type default isn't secret")
    func defaultTypeIsNotSecret() throws {
        let environment = try Fixture.environment("postman-cli-action/postman-echo-environment.json")

        #expect(environment.values.map(\.key) == ["baseUrl", "userName", "environmentName", "testParam"])
        #expect(environment.values.map(\.type) == ["default", "default", "default", "default"])
        #expect(environment.values.map(\.isSecret) == [false, false, false, false])
    }

    @Test("A value of type secret is secret, from a snippet because no licensed fixture has one")
    func secretTypeIsSecret() throws {
        let environment = try decodeEnvironment(type: "secret")

        let value = try #require(environment.values.only)

        #expect(value.type == "secret")
        #expect(value.isSecret)
    }

    @Test("A type PostmanKit doesn't know keeps its name and isn't secret")
    func unknownTypeKeepsItsName() throws {
        let environment = try decodeEnvironment(type: "vault")

        let value = try #require(environment.values.only)

        #expect(value.type == "vault")
        #expect(!value.isSecret)
    }

    @Test("A file with a byte order mark decodes")
    func decodesByteOrderMark() throws {
        let path = "newman/bom-in-environment-file.postman_environment.json"
        #expect(try Fixture.data(path).starts(with: [0xEF, 0xBB, 0xBF]))

        let environment = try Fixture.environment(path)

        #expect(environment.values.map(\.key) == ["fo/o", "b\\ar"])
    }

    private func decodeEnvironment(type: String) throws -> PostmanEnvironment {
        let json = #"{ "values": [{ "key": "token", "value": "abc", "type": "\#(type)", "enabled": true }] }"#
        return try JSONDecoder().decode(PostmanEnvironment.self, from: Data(json.utf8))
    }

}
