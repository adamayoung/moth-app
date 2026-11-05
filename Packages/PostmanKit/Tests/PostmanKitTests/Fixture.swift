//  Fixture.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit
import Testing

enum Fixture {

    static func data(_ path: String) throws -> Data {
        try Data(contentsOf: url(path))
    }

    static func text(_ path: String) throws -> String {
        try #require(String(bytes: data(path), encoding: .utf8))
    }

    static func url(_ path: String) throws -> URL {
        let resources = try #require(Bundle.module.resourceURL)
        return resources.appending(path: "Fixtures/\(path)")
    }

    static func collection(_ path: String) throws -> PostmanCollection {
        try JSONDecoder().decode(PostmanCollection.self, from: data(path))
    }

    static func environment(_ path: String) throws -> PostmanEnvironment {
        try JSONDecoder().decode(PostmanEnvironment.self, from: data(path))
    }

    static func nonV21Contents(_ path: String) throws -> NonV21Contents {
        try JSONDecoder().decode(NonV21Contents.self, from: data(path))
    }

    /// Reads a file past `PostmanCollection`'s schema check. The only object-form description Postman
    /// publishes under Apache-2.0 sits in a v2.0.0 file, and the form is the same in v2.1.
    struct NonV21Contents: Decodable {

        let info: PostmanInfo
        let item: [PostmanItem]

    }

}
