//  PostmanDisabledRowTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import PostmanKit
import Testing

struct PostmanDisabledRowTests {

    @Test("An app export keeps which headers and query parameters are disabled")
    func appExportKeepsDisabledRows() throws {
        let collection = try Fixture.collection("openapi-to-postman/collection.json")

        let request = try #require(collection.request(named: "Read a spacecraft"))

        #expect(request.headers.map(\.key) == ["Accept", "h2", "h3"])
        #expect(request.headers.map(\.isEnabled) == [false, false, true])
        let query = try #require(request.url?.query)
        #expect(query.map(\.key) == ["qu2", "qssu2"])
        #expect(query.map(\.isEnabled) == [false, true])
    }

    @Test("A disabled query parameter stays disabled beside enabled ones")
    func queryParameterStaysDisabled() throws {
        let collection = try Fixture.collection("postman-code-generators/basicCollection.json")

        let query = try #require(collection.request(named: "GET Request with disabled query")?.url?.query)

        #expect(query.map(\.isEnabled) == [true, true, false])
    }

    @Test("A disabled header stays disabled beside enabled ones")
    func headerStaysDisabled() throws {
        let collection = try Fixture.collection("postman-code-generators/basicCollection.json")

        let headers = try #require(collection.request(named: "Request Headers with disabled headers")?.headers)

        #expect(headers.map(\.key) == ["my-sample-header", "not-disabled-header", "disabled header"])
        #expect(headers.map(\.isEnabled) == [true, true, false])
    }

}
