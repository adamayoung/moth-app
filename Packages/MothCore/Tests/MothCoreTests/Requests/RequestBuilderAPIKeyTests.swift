//  RequestBuilderAPIKeyTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestBuilderAPIKeyTests {

    private let builder = RequestBuilder()
    private let secret = SecretReference(identifier: "secret")

    @Test("A key added to the header goes out as a header")
    func header() async throws {
        let built = try await build(name: "X-Key", value: "abc", location: .header)

        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Key") == "abc")
        #expect(built.notices.isEmpty)
    }

    @Test("A key added to query params goes out on the URL, and not as a header")
    func query() async throws {
        let built = try await build(name: "api_key", value: "abc", location: .query)

        #expect(built.urlRequest.url?.absoluteString == "https://example.com?api_key=abc")
        #expect(built.urlRequest.allHTTPHeaderFields?.isEmpty != false)
    }

    @Test("A header replaces every manual row of the same name, in any case", arguments: ["X-Key", "x-key"])
    func headerReplacesManualRows(rowName: String) async throws {
        let built = try await build(
            name: "X-Key",
            value: "abc",
            location: .header,
            headers: [KeyValue(key: rowName, value: "one"), KeyValue(key: rowName, value: "two")]
        )

        #expect(built.urlRequest.allHTTPHeaderFields?.count == 1)
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Key") == "abc")
    }

    @Test("A query key replaces a manual row of the same name, and keeps the others in order")
    func queryReplacesManualRow() async throws {
        let built = try await build(
            name: "api_key",
            value: "abc",
            location: .query,
            queryParameters: [
                KeyValue(key: "limit", value: "10"),
                KeyValue(key: "api_key", value: "manual"),
                KeyValue(key: "API_KEY", value: "other")
            ]
        )

        #expect(built.urlRequest.url?.query == "limit=10&API_KEY=other&api_key=abc")
    }

    @Test("A query key replaces a pair typed into the URL, however it is encoded, and keeps its fragment")
    func queryReplacesPairInTheURL() async throws {
        let built = try await build(
            name: "api key",
            value: "abc",
            location: .query,
            url: "https://example.com/a?api%20key=typed&b=c=d&flag#top"
        )

        #expect(built.urlRequest.url?.absoluteString == "https://example.com/a?b=c=d&flag&api%20key=abc#top")
    }

    @Test(
        "A query key percent-encodes its name and value",
        arguments: [
            ("api key", "a&b=c", "api%20key=a%26b%3Dc"),
            ("clé", "日本", "cl%C3%A9=%E6%97%A5%E6%9C%AC"),
            ("a+b", "100%", "a%2Bb=100%25")
        ]
    )
    func queryIsPercentEncoded(name: String, value: String, expected: String) async throws {
        let built = try await build(name: name, value: value, location: .query)

        #expect(built.urlRequest.url?.query(percentEncoded: true) == expected)
    }

    @Test("An empty value goes out empty", arguments: [
        (APIKeyLocation.query, "https://example.com?key="),
        (.header, "https://example.com")
    ])
    func emptyValue(location: APIKeyLocation, expected: String) async throws {
        let built = try await build(name: "key", value: "", location: location)

        #expect(built.urlRequest.url?.absoluteString == expected)
        #expect(built.notices.isEmpty)
    }

    @Test("An empty key sends no key and leaves manual rows alone, and is reported", arguments: [
        APIKeyLocation.header,
        .query
    ])
    func emptyKey(location: APIKeyLocation) async throws {
        let built = try await build(
            name: "",
            value: "abc",
            location: location,
            queryParameters: [KeyValue(key: "limit", value: "10")],
            headers: [KeyValue(key: "X-Key", value: "manual")]
        )

        #expect(built.urlRequest.url?.absoluteString == "https://example.com?limit=10")
        #expect(built.urlRequest.allHTTPHeaderFields == ["X-Key": "manual"])
        #expect(built.notices == [.apiKeyWithoutName])
    }

    @Test("An empty key is the same note as a credential with no value")
    func emptyKeyNote() {
        #expect(ResponseNote.notes(unresolved: [], notices: [.apiKeyWithoutName]) == [.missingCredential])
    }

    @Test("A key with no stored value sends nothing, because the resolver has reported it", arguments: [
        APIKeyLocation.header,
        .query
    ])
    func missingValue(location: APIKeyLocation) async throws {
        let built = try await build(
            name: "X-Key",
            value: nil,
            location: location,
            headers: [KeyValue(key: "X-Key", value: "manual")]
        )

        #expect(built.urlRequest.url?.absoluteString == "https://example.com")
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Key") == "manual")
        #expect(built.notices.isEmpty)
    }

    @Test(
        "A key a header cannot carry is an error, so a manual header cannot go out in its place",
        arguments: [
            ("X-Key", "abc\n"),
            ("X-Key", "a\r\nX-Injected: 1"),
            ("X-Key", "日本"),
            ("X Key", "abc"),
            ("X-Key\n", "abc"),
            ("{{undefined}}", "abc")
        ]
    )
    func unsendableHeader(name: String, value: String) async {
        await #expect(throws: RequestBuildError.invalidAPIKey) {
            try await build(
                name: name,
                value: value,
                location: .header,
                headers: [KeyValue(key: "X-Key", value: "manual")]
            )
        }
    }

    @Test("What a header can't carry is fine in the query, because it is percent-encoded")
    func lineBreakInTheQuery() async throws {
        let built = try await build(name: "key", value: "a\nb", location: .query)

        #expect(built.urlRequest.url?.query(percentEncoded: true) == "key=a%0Ab")
    }

    @Test("The API key error reads as the app shows it")
    func invalidAPIKeyDescription() {
        #expect(RequestBuildError.invalidAPIKey.errorDescription == "This API key can’t be sent in a header.")
    }

    private func build(
        name: String,
        value: String?,
        location: APIKeyLocation,
        url: String = "https://example.com",
        queryParameters: [KeyValue] = [],
        headers: [KeyValue] = []
    ) async throws -> BuiltRequest {
        try await builder.build(ResolvedRequest(
            url: url,
            queryParameters: queryParameters,
            headers: headers,
            auth: .apiKey(APIKeyAuth(name: name, value: secret, location: location)),
            credentials: value.map { [secret: $0] } ?? [:]
        ))
    }

}
