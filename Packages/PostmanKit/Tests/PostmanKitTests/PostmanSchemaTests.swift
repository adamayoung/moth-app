//  PostmanSchemaTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanSchemaTests {

    @Test("The Collection v2.1 schema URL is recognised")
    func recognisesCollectionV21() {
        let url = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"

        #expect(PostmanSchema(rawValue: url) == .collectionV21)
    }

    @Test(
        "Any other schema is rejected",
        arguments: [
            "https://schema.getpostman.com/json/collection/v2.0.0/collection.json",
            "https://schema.getpostman.com/json/collection/v1.0.0/collection.json",
            "https://schema.getpostman.com/json/draft-07/collection/v2.1.0/collection.json",
            "https://example.com/collection.json",
            ""
        ]
    )
    func rejectsOtherSchemas(url: String) {
        #expect(PostmanSchema(rawValue: url) == nil)
    }

}
