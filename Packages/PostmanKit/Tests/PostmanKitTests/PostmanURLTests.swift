//  PostmanURLTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanURLTests {

    @Test("A URL in object form keeps its raw text, host, path and query in order")
    func decodesObjectForm() throws {
        let collection = try Fixture.collection("postman-code-generators/basicCollection.json")

        let url = try #require(collection.request(named: "GET Request with disabled query")?.url)

        #expect(url.raw == "https://postman-echo.com/get?test=123&anotherone=232")
        #expect(url.protocolName == "https")
        #expect(url.host == ["postman-echo", "com"])
        #expect(url.path == ["get"])
        #expect(url.query.map(\.key) == ["test", "anotherone", "anotheroneone"])
        #expect(url.query.map(\.value) == ["123", "232", "sdfsdf"])
    }

    @Test("A URL in object form keeps its port and fragment")
    func decodesPortAndFragment() throws {
        let contents = try Fixture.nonV21Contents(
            "postman-collection-transformer/v2.1.0/proper-description-parsing.json"
        )

        let url = try #require(contents.item.request(named: "request with hostname as variable")?.url)

        #expect(url.port == "2002")
        #expect(url.hash == "/awesomeshit")
    }

    @Test("A URL in string form keeps its text as the raw URL and has no components")
    func decodesStringForm() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/binary-upload.json")

        let url = try #require(collection.request(named: "http://httpbin.org/post")?.url)

        #expect(url.raw == "http://echo.postman.com/post")
        #expect(url.host.isEmpty)
        #expect(url.path.isEmpty)
        #expect(url.query.isEmpty)
    }

}
