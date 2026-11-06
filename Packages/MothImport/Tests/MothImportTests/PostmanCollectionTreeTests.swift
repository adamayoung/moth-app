//  PostmanCollectionTreeTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanCollectionTreeTests {

    @Test("Folders keep their nesting and names")
    func keepsNesting() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        #expect(collection.name == "this")
        let outer = try #require(collection.children.first?.folder)
        #expect(collection.children.count == 1)
        #expect(outer.name == "folder 1")
        let middle = try #require(outer.children.first?.folder)
        #expect(middle.name == "folder 1.2")
        let inner = try #require(middle.children.first?.folder)
        #expect(inner.name == "folder 1.2.1")
        #expect(inner.children.compactMap(\.request).map(\.name) == ["Read a spacecraft"])
    }

    @Test("Requests keep their file order and methods")
    func keepsOrderAndMethods() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")

        let requests = collection.children.compactMap(\.request)

        #expect(requests.map(\.name) == [
            "Request Headers (With special Characters)",
            "Request Headers",
            "Request Headers with disabled headers",
            "GET Request with disabled query",
            "POST Raw Text",
            "POST json with raw",
            "POST graphql body(json) with raw",
            "POST javascript with raw",
            "POST text/xml with raw",
            "POST text/html with raw",
            "POST urlencoded data",
            "PUT Request",
            "PATCH Request",
            "DELETE Request"
        ])
        #expect(requests.map(\.method.rawValue) == [
            "GET", "GET", "GET", "GET", "POST", "POST", "POST", "POST", "POST", "POST", "POST", "PUT", "PATCH", "DELETE"
        ])
    }

    @Test("A lower-case method is upper-cased, as postman-collection's Request does")
    func upperCasesMethods() async throws {
        let request = try await Fixture.snippetRequest(#"{ "method": "post" }"#)

        #expect(request.method == .post)
    }

    @Test("A method Moth has no constant for keeps its spelling")
    func keepsCustomMethods() async throws {
        let collection = try await Fixture.collection("postman-code-generators/unsupportedMethods.json")

        #expect(collection.children.compactMap(\.request).map(\.method.rawValue) == [
            "LINK", "UNLINK", "LOCK", "UNLOCK", "PROPFIND", "PURGE", "COPY"
        ])
    }

}
