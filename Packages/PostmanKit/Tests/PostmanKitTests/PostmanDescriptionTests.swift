//  PostmanDescriptionTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanDescriptionTests {

    @Test("A description in string form keeps its text and has no type")
    func decodesStringForm() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/nestedEntities.json")

        let description = collection.info.description

        #expect(description?
            .content == "A simple V1 collection to elucidate nested auth helpers, variables, and scripts")
        #expect(description?.type == nil)
    }

    @Test("A description in object form keeps its content and type")
    func decodesObjectForm() throws {
        let contents = try Fixture.nonV21Contents(
            "postman-collection-transformer/v2.1.0/proper-description-parsing.json"
        )

        #expect(contents.info.description?.content == "V2 supported collection description in object format")
        #expect(contents.info.description?.type == "text/plain")
        let request = contents.item.request(named: "request with hostname as variable")
        #expect(request?.description?.content == "V2 supported request description in object format")
    }

    @Test("A null description decodes as absent")
    func decodesNullAsAbsent() throws {
        let collection = try Fixture.collection("postman-code-generators/unsupportedMethods.json")

        let request = try #require(collection.request(named: "LINK request"))

        #expect(request.description == nil)
    }

}
