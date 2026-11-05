//  PostmanBodyTests.swift
//  PostmanKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import PostmanKit
import Testing

struct PostmanBodyTests {

    private static let basicCollection = "postman-code-generators/basicCollection.json"

    @Test("A raw body keeps its text")
    func decodesRaw() throws {
        let collection = try Fixture.collection(Self.basicCollection)

        let body = try #require(collection.request(named: "POST Raw Text")?.body)

        guard case .raw(let text, let language) = body else {
            Issue.record("Expected a raw body, found \(body)")
            return
        }
        #expect(text?.hasPrefix("Duis posuere augue vel cursus pharetra.") == true)
        #expect(language == nil)
    }

    @Test("A raw body keeps its language option")
    func decodesRawLanguage() throws {
        let collection = try Fixture.collection("openapi-to-postman/internalRefsCollection.json")

        let body = try #require(collection.request(named: "/inventory/:searchString")?.body)

        guard case .raw(_, let language) = body else {
            Issue.record("Expected a raw body, found \(body)")
            return
        }
        #expect(language == "json")
    }

    @Test("A urlencoded body keeps its rows in order")
    func decodesURLEncoded() throws {
        let collection = try Fixture.collection(Self.basicCollection)

        let body = try #require(collection.request(named: "POST urlencoded data")?.body)

        guard case .urlencoded(let rows) = body else {
            Issue.record("Expected a urlencoded body, found \(body)")
            return
        }
        #expect(rows.map(\.key) == ["1", "2", "'3'", "\"4\"", "Special", "more", "non-ascii"])
        #expect(rows.first?.value == "'a'")
    }

    @Test("A form data body keeps its rows in order, and a disabled row stays disabled")
    func decodesFormData() throws {
        let collection = try Fixture.collection("postman-code-generators/formdataCollection.json")

        let body = try #require(
            collection.request(named: "POST multipart/form-data with text parameters")?.body
        )

        guard case .formdata(let rows) = body else {
            Issue.record("Expected a form data body, found \(body)")
            return
        }
        #expect(rows.map(\.key) == ["pl", "qu", "sa", "Special", "Not Select", "more"])
        #expect(rows.map(\.isEnabled) == [true, true, true, true, false, true])
        #expect(rows.first?.type == "text")
        #expect(rows.first?.value == "'a'")
        #expect(rows.first?.sources.isEmpty == true)
    }

    @Test("A form data file row keeps its source from a string or an array")
    func decodesFormDataSources() throws {
        let collection = try Fixture.collection("postman-code-generators/formdataFileCollection.json")

        let body = try #require(
            collection.request(named: "Single/multiple file upload via form-data")?.body
        )

        guard case .formdata(let rows) = body else {
            Issue.record("Expected a form data body, found \(body)")
            return
        }
        #expect(rows.map(\.type) == ["file", "file"])
        let fileNames = rows.map { $0.sources.map { URL(filePath: $0).lastPathComponent } }
        #expect(fileNames == [["dummyFile1.txt"], ["dummyFile2.txt", "dummyFile3.txt"]])
    }

    @Test("A file body keeps its source")
    func decodesFile() throws {
        let collection = try Fixture.collection("postman-collection-transformer/v2.1.0/binary-upload.json")

        let body = collection.request(named: "http://httpbin.org/post")?.body

        #expect(body == .file(src: "sample.txt", content: nil))
    }

    @Test("A GraphQL body keeps its query and variables")
    func decodesGraphQL() throws {
        let collection = try Fixture.collection(Self.basicCollection)

        let body = try #require(collection.request(named: "POST graphql body(json) with raw")?.body)

        guard case .graphql(let query, let variables) = body else {
            Issue.record("Expected a GraphQL body, found \(body)")
            return
        }
        #expect(query?.hasPrefix("{\n  findScenes(") == true)
        #expect(variables == .string("{\n\t\"variable_key\": \"variable_value\"\n}"))
    }

    @Test("A body with no mode decodes as empty")
    func decodesEmpty() throws {
        let collection = try Fixture.collection("postman-code-generators/unsupportedMethods.json")

        #expect(collection.request(named: "UNLOCK request")?.body == .empty)
    }

    @Test("A request with no body has none")
    func decodesAbsentBody() throws {
        let collection = try Fixture.collection(Self.basicCollection)

        let request = try #require(collection.request(named: "Request Headers"))

        #expect(request.body == nil)
    }

    @Test("A body in an unknown mode keeps the mode's name")
    func keepsUnknownMode() throws {
        let json = #"{ "mode": "soap", "soap": "<envelope />" }"#

        let body = try JSONDecoder().decode(PostmanBody.self, from: Data(json.utf8))

        #expect(body == .unknown("soap"))
    }

}
