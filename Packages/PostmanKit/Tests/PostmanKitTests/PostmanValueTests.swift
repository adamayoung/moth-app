//  PostmanValueTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit
import Testing

struct PostmanValueTests {

    @Test(
        "A value keeps its JSON type",
        arguments: [
            (#""text""#, PostmanValue.string("text")),
            ("12.5", .number(12.5)),
            ("false", .bool(false)),
            ("null", .null),
            (#"["a", 1]"#, .array([.string("a"), .number(1)])),
            (#"{ "a": true }"#, .object(["a": .bool(true)]))
        ]
    )
    func keepsItsType(json: String, expected: PostmanValue) throws {
        #expect(try JSONDecoder().decode(PostmanValue.self, from: Data(json.utf8)) == expected)
    }

}
