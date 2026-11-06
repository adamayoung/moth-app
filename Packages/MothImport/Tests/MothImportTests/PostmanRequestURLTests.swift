//  PostmanRequestURLTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

struct PostmanRequestURLTests {

    private static let spacecraftRequest = "Read a spacecraft"

    @Test("A query that became rows leaves the template, so it can't be sent twice")
    func cutsQueryFromTemplate() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        let request = try collection.request(named: Self.spacecraftRequest)

        #expect(request.urlTemplate == "{{baseUrl}}/spacecrafts/:spacecraftId")
    }

    @Test("Query parameters map, and a disabled one stays disabled")
    func mapsQueryParameters() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        let parameters = try collection.request(named: Self.spacecraftRequest).queryParameters

        #expect(parameters.map(\.key) == ["qu2", "qssu2"])
        #expect(parameters.map(\.value) == ["<string>", "ipsum nostrud culpa do"])
        #expect(parameters.map(\.isEnabled) == [false, true])
    }

    @Test("Headers map, and a disabled one stays disabled")
    func mapsHeaders() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        let headers = try collection.request(named: Self.spacecraftRequest).headers

        #expect(headers.map(\.key) == ["Accept", "h2", "h3"])
        #expect(headers.map(\.value) == ["application/json", "", ""])
        #expect(headers.map(\.isEnabled) == [false, false, true])
    }

    @Test("Path variables map")
    func mapsPathVariables() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/collection.json")

        let parameters = try collection.request(named: Self.spacecraftRequest).pathParameters

        #expect(parameters.map(\.key) == ["spacecraftId"])
        #expect(parameters.map(\.value) == ["<string>"])
        #expect(parameters.map(\.isEnabled) == [true])
    }

    @Test("A URL with no raw form is rebuilt from its parts")
    func rebuildsURLFromParts() async throws {
        let collection = try await Fixture.collection("openapi-to-postman/internalRefsCollection.json")

        let request = try collection.request(named: "searches inventory")

        #expect(request.urlTemplate == "{{baseUrl}}/inventory/:searchString")
        #expect(request.queryParameters.map(\.key) == ["skip"])
        #expect(request.pathParameters.map(\.value) == ["magna"])
    }

    @Test("A URL given as text is the template")
    func usesTextURL() async throws {
        let collection = try await Fixture.collection("postman-collection-transformer/v2.1.0/helpers.json")

        let request = try collection.request(named: "test bearer auth success")

        #expect(request.urlTemplate == "http://echo.postman.com/auth/bearer")
    }

    @Test("A URL given as text keeps its query, because it has no rows to carry it")
    func keepsQueryOfTextURL() async throws {
        let request = try await Fixture.snippetRequest(#"{ "method": "GET", "url": "https://a.test/b?c=d" }"#)

        #expect(request.urlTemplate == "https://a.test/b?c=d")
        #expect(request.queryParameters.isEmpty)
    }

    @Test("Cutting the query keeps the fragment")
    func keepsFragment() async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "method": "GET",
            "url": {
                "raw": "https://a.test/b?c=d#e?f",
                "query": [{ "key": "c", "value": "d" }]
            }
        }
        """#)

        #expect(request.urlTemplate == "https://a.test/b#e?f")
    }

    @Test("Rebuilding a URL takes its protocol, dotted host, port and fragment")
    func rebuildsEveryPart() async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "method": "GET",
            "url": {
                "protocol": "https",
                "host": ["a", "test"],
                "port": "8080",
                "path": ["b", "c"],
                "hash": "d"
            }
        }
        """#)

        #expect(request.urlTemplate == "https://a.test:8080/b/c#d")
    }

    @Test("A row written already encoded is stored decoded, because RequestBuilder encodes rows")
    func decodesEncodedQueryRows() async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "url": {
                "raw": "https://a.test/?q%201=hello%20world",
                "query": [
                    { "key": "q%201", "value": "hello%20world" },
                    { "key": "rate", "value": "100%" }
                ]
            }
        }
        """#)

        #expect(request.queryParameters.map(\.key) == ["q 1", "rate"])
        #expect(request.queryParameters.map(\.value) == ["hello world", "100%"])
    }

    @Test("A path variable written already encoded is stored decoded")
    func decodesEncodedPathVariables() async throws {
        let request = try await Fixture.snippetRequest(#"""
        {
            "url": {
                "raw": "https://a.test/:id",
                "variable": [{ "key": "id", "value": "a%2Fb" }]
            }
        }
        """#)

        #expect(request.pathParameters.map(\.value) == ["a/b"])
    }

    @Test("A request with no URL has an empty template, and no method means GET")
    func handlesMissingURLAndMethod() async throws {
        let request = try await Fixture.snippetRequest("{}")

        #expect(request.urlTemplate.isEmpty)
        #expect(request.method == .get)
    }

}
