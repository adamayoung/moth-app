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

    static func url(_ path: String) throws -> URL {
        let resources = try #require(Bundle.module.resourceURL)
        return resources.appending(path: "Fixtures/\(path)")
    }

    static func collection(_ path: String) throws -> PostmanCollection {
        try JSONDecoder().decode(PostmanCollection.self, from: data(path))
    }

}
