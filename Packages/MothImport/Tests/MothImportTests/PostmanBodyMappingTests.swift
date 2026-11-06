//  PostmanBodyMappingTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanBodyMappingTests {

    private static let formFilePrefix = "/Users/vishalkumar.shingala@postman.com/pm/postman-code-generators/"

    @Test("Raw text with no language keeps its content and leaves the content type to its header")
    func mapsRawWithNoLanguage() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")
        let request = try collection.request(named: "POST Raw Text")

        guard case .raw(let content, let contentType) = request.body else {
            Issue.record("Expected a raw body, got \(request.body)")
            return
        }

        #expect(content.hasPrefix("Duis posuere augue vel cursus pharetra."))
        #expect(content.hasSuffix("!@#$%^&*()_+-=,.<>/?"))
        #expect(contentType.isEmpty)
        #expect(request.headers.map(\.value) == ["text/plain"])
    }

    @Test("A raw body's language gives its content type")
    func mapsRawLanguageFromFixture() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/internalRefsCollection.json")
        let request = try collection.request(named: "/inventory/:searchString")

        guard case .raw(_, let contentType) = request.body else {
            Issue.record("Expected a raw body, got \(request.body)")
            return
        }

        #expect(contentType == "application/json")
    }

    @Test(
        "Each raw language has its content type, from a snippet because the fixtures hold only json",
        arguments: [
            ("json", "application/json"),
            ("xml", "application/xml"),
            ("html", "text/html"),
            ("javascript", "application/javascript"),
            ("text", "text/plain"),
            ("yaml", "")
        ]
    )
    func mapsEachRawLanguage(language: String, contentType: String) async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "body": {
                "mode": "raw",
                "raw": "a",
                "options": { "raw": { "language": "\#(language)" } }
            }
        }
        """#)

        #expect(request.body == .raw(content: "a", contentType: contentType))
    }

    @Test("URL-encoded rows keep their keys, values and order")
    func mapsURLEncoded() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")
        let request = try collection.request(named: "POST urlencoded data")

        guard case .urlEncoded(let rows) = request.body else {
            Issue.record("Expected a URL-encoded body, got \(request.body)")
            return
        }

        #expect(rows.map(\.key) == ["1", "2", "'3'", "\"4\"", "Special", "more", "non-ascii"])
        #expect(rows.first?.value == "'a'")
        #expect(rows.last?.value == "테스트")
    }

    @Test("Form text fields keep their values, and a disabled one stays disabled")
    func mapsFormDataText() async throws {
        let collection = try await Fixture.collection("postman-code-generators/formdataCollection.json")
        let request = try collection.request(named: "POST multipart/form-data with text parameters")

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected a form-data body, got \(request.body)")
            return
        }

        #expect(fields.map(\.key) == ["pl", "qu", "sa", "Special", "Not Select", "more"])
        #expect(fields.first?.value == .text("'a'"))
        #expect(fields.map(\.isEnabled) == [true, true, true, true, false, true])
    }

    @Test("Form file fields keep their paths, whether the file gives one or several")
    func mapsFormDataFiles() async throws {
        let collection = try await Fixture.collection("postman-code-generators/formdataFileCollection.json")
        let request = try collection.request(named: "Single/multiple file upload via form-data")

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected a form-data body, got \(request.body)")
            return
        }

        #expect(fields.map(\.key) == ["single file", "multiple files"])
        #expect(fields.first?.value == .file(paths: ["\(Self.formFilePrefix)dummyFile1.txt"]))
        #expect(fields.last?.value == .file(paths: [
            "\(Self.formFilePrefix)dummyFile2.txt",
            "\(Self.formFilePrefix)dummyFile3.txt"
        ]))
    }

    @Test("A form field keeps its content type")
    func mapsFormDataContentType() async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "body": {
                "mode": "formdata",
                "formdata": [{ "key": "a", "value": "b", "type": "text", "contentType": "application/json" }]
            }
        }
        """#)

        guard case .formData(let fields) = request.body else {
            Issue.record("Expected a form-data body, got \(request.body)")
            return
        }

        #expect(fields.map(\.contentType) == ["application/json"])
    }

    @Test("A file body is stored as binary with its path")
    func mapsBinary() async throws {
        let collection = try await Fixture.collection("postman-collection-transformer/v2.1.0/binary-upload.json")

        let request = try collection.request(named: "http://httpbin.org/post")

        #expect(request.body == .binary(filePath: "sample.txt"))
    }

    @Test("A GraphQL body is stored with its query and variables")
    func mapsGraphQL() async throws {
        let collection = try await Fixture.collection("postman-code-generators/basicCollection.json")
        let request = try collection.request(named: "POST graphql body(json) with raw")

        guard case .graphQL(let query, let variables) = request.body else {
            Issue.record("Expected a GraphQL body, got \(request.body)")
            return
        }

        #expect(query.hasPrefix("{\n  findScenes("))
        #expect(variables == "{\n\t\"variable_key\": \"variable_value\"\n}")
    }

    @Test("GraphQL variables given as an object become JSON text")
    func mapsGraphQLObjectVariables() async throws {
        let request = try await Fixture.snippetRequest(#"""
        { "body": { "mode": "graphql", "graphql": { "query": "{ a }", "variables": { "b": 1, "c": "/d" } } } }
        """#)

        #expect(request.body == .graphQL(query: "{ a }", variables: #"{"b":1,"c":"/d"}"#))
    }

    @Test("An empty body and a missing one are no body")
    func mapsEmptyBodies() async throws {
        let collection = try await Fixture.collection("postman-collection-transformer/v2.1.0/nestedEntities.json")
        let missing = try await Fixture.collection("openapi-to-postman/collection.json")

        #expect(try collection.request(named: "Basic").body == .none)
        #expect(try missing.request(named: "Read a spacecraft").body == .none)
    }

    @Test("A body mode Moth doesn't know is no body, and is counted")
    func countsUnknownMode() async throws {
        let result = try await Fixture.importingSnippet(items: #"""
        [{ "name": "a", "request": { "body": { "mode": "telepathy" } } }]
        """#)

        #expect(result.collection?.requests.first?.body == RequestBody.none)
        #expect(result.skipped.bodies == 1)
    }

    @Test("A file body's inline content can't be stored, so it's counted")
    func countsInlineFileContent() async throws {
        let result = try await Fixture.importingSnippet(items: #"""
        [{ "name": "a", "request": { "body": { "mode": "file", "file": { "content": "abc" } } } }]
        """#)

        #expect(result.collection?.requests.first?.body == .binary(filePath: nil))
        #expect(result.skipped.bodies == 1)
    }

}
