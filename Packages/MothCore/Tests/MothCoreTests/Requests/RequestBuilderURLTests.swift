//  RequestBuilderURLTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestBuilderURLTests {

    private let builder = RequestBuilder()

    @Test("Enabled query parameters are added, and disabled ones are not")
    func enabledQueryParameters() async throws {
        let url = try await builtURL(
            "https://example.com/users",
            queryParameters: [
                KeyValue(key: "page", value: "2"),
                KeyValue(key: "draft", value: "true", isEnabled: false)
            ]
        )

        #expect(url == "https://example.com/users?page=2")
    }

    @Test("A query parameter with an empty key is not added")
    func emptyQueryKey() async throws {
        let url = try await builtURL(
            "https://example.com",
            queryParameters: [KeyValue(key: "", value: "orphan"), KeyValue(key: "page", value: "")]
        )

        #expect(url == "https://example.com?page=")
    }

    @Test("Query keys and values are encoded, so reserved characters survive")
    func queryEncoding() async throws {
        let url = try await builtURL(
            "https://example.com/search",
            queryParameters: [KeyValue(key: "a b", value: "x&y=z+1/é%20")]
        )

        #expect(url == "https://example.com/search?a%20b=x%26y%3Dz%2B1%2F%C3%A9%2520")
    }

    @Test("Parameters follow a query already in the URL, which stays as written")
    func existingQuery() async throws {
        let url = try await builtURL(
            "https://example.com/users?sort=name%20asc",
            queryParameters: [KeyValue(key: "page", value: "2")]
        )

        #expect(url == "https://example.com/users?sort=name%20asc&page=2")
    }

    @Test("A path variable is substituted and encoded")
    func pathVariable() async throws {
        let url = try await builtURL(
            "https://example.com/users/:id/posts",
            pathParameters: [KeyValue(key: "id", value: "a/b c")]
        )

        #expect(url == "https://example.com/users/a%2Fb%20c/posts")
    }

    @Test("A disabled path variable stays as written")
    func disabledPathVariable() async throws {
        let url = try await builtURL(
            "https://example.com/users/:id",
            pathParameters: [KeyValue(key: "id", value: "1", isEnabled: false)]
        )

        #expect(url == "https://example.com/users/:id")
    }

    @Test("A path variable with no value stays as written, so a blank cannot change the route")
    func emptyPathVariable() async throws {
        let url = try await builtURL(
            "https://example.com/users/:id/sessions",
            pathParameters: [KeyValue(key: "id", value: "")]
        )

        #expect(url == "https://example.com/users/:id/sessions")
    }

    @Test("A path variable named like a port, or matching only part of a segment, changes nothing")
    func pathVariableOnlyMatchesWholePathSegments() async throws {
        let url = try await builtURL(
            "https://example.com:8080/v:id/x?a=:id",
            pathParameters: [KeyValue(key: "8080", value: "1"), KeyValue(key: "id", value: "2")]
        )

        #expect(url == "https://example.com:8080/v:id/x?a=:id")
    }

    @Test(
        "A URL with no scheme is sent as http",
        arguments: [
            ("example.com/users", "http://example.com/users"),
            ("localhost:8080/users", "http://localhost:8080/users"),
            ("example.com/next?to=https://other.test", "http://example.com/next?to=https://other.test"),
            ("  example.com  ", "http://example.com"),
            ("192.0.2.1:8080/users", "http://192.0.2.1:8080/users"),
            ("[::1]:8080/users", "http://[::1]:8080/users")
        ]
    )
    func defaultScheme(address: String, expected: String) async throws {
        #expect(try await builtURL(address) == expected)
    }

    @Test(
        "A scheme is kept in any case",
        arguments: ["https://example.com", "http://example.com", "HTTPS://example.com"]
    )
    func schemeKept(address: String) async throws {
        #expect(try await builtURL(address).lowercased() == address.lowercased())
    }

    @Test(
        "An empty or unsendable URL is an error",
        arguments: [
            "",
            "   ",
            "http://",
            "https://?page=1",
            "http://example.com:port",
            "http://[example.com",
            "file:///etc/hosts",
            "ftp://example.com",
            "file:/etc/hosts",
            "mailto:a@example.com",
            "example.com:port",
            "http://example.com:99999",
            "http://example.com:0"
        ]
    )
    func invalidURL(address: String) async {
        await #expect(throws: RequestBuildError.invalidURL) {
            try await builder.build(ResolvedRequest(url: address))
        }
    }

    @Test("The URL error reads as the app shows it")
    func invalidURLDescription() {
        #expect(RequestBuildError.invalidURL.errorDescription == "This URL isn’t valid.")
    }

    private func builtURL(
        _ url: String,
        queryParameters: [KeyValue] = [],
        pathParameters: [KeyValue] = []
    ) async throws -> String {
        let built = try await builder.build(
            ResolvedRequest(url: url, queryParameters: queryParameters, pathParameters: pathParameters)
        )

        return try #require(built.urlRequest.url?.absoluteString)
    }

}
