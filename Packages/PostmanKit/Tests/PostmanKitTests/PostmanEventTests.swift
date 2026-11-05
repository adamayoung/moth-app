//  PostmanEventTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanEventTests {

    @Test("Scripts decode at collection, folder and request level, in file order")
    func decodesEachLevel() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/nestedEntities.json")

        #expect(collection.events.map(\.listen) == ["test", "prerequest"])
        #expect(collection.events.first?.script?.type == "text/javascript")
        #expect(collection.events.first?.script?.exec == ["console.log('Collection level test script');"])
        #expect(collection.events.first?.isEnabled == true)

        let folder = try #require(collection.items.first?.folder)
        #expect(folder.events.first?.script?.exec == ["console.log('Folder level test script');"])

        let request = try #require(folder.items.requestItems.only)
        #expect(request.events.last?.script?.exec == ["console.log('Request level pre request script');"])
    }

    @Test("A script whose exec is a single string keeps it as one line")
    func decodesStringExec() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/helpers.json")

        let item = try #require(collection.items.requestItems.first { $0.name == "test bearer auth success" })

        let exec = try #require(item.events.only?.script?.exec)
        #expect(
            exec ==
                [
                    "var response = JSON.parse(responseBody); tests['Bearer auth should pass'] = response.status === 'pass';"
                ]
        )
    }

}
