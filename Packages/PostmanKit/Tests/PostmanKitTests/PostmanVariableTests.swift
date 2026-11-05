//  PostmanVariableTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanVariableTests {

    @Test("Variables decode at collection, folder and request level")
    func decodesEachLevel() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/nestedEntities.json")

        let collectionVariable = try #require(collection.variables.only)
        #expect(collectionVariable.key == "collection")
        #expect(collectionVariable.value == .string("variable"))
        #expect(collectionVariable.type == "string")
        #expect(collectionVariable.description?.content == "This is a collection level variable")
        #expect(collectionVariable.isEnabled)

        let folder = try #require(collection.items.first?.folder)
        #expect(folder.variables.map(\.key) == ["folder"])

        let request = try #require(folder.items.requestItems.only)
        #expect(request.variables.map(\.key) == ["request"])
    }

    @Test("A URL keeps its path variables")
    func decodesPathVariables() throws {
        let collection = try Fixture.collection("openapi-to-postman/collection.json")

        let url = try #require(collection.request(named: "Read a spacecraft")?.url)

        let variable = try #require(url.variables.only)
        #expect(variable.key == "spacecraftId")
        #expect(variable.value == .string("<string>"))
    }

}
