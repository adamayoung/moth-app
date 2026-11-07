//  WrittenAddressTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct WrittenAddressTests {

    @Test("A URL with no rows stays as written")
    func plainURL() {
        let request = ResolvedRequest(url: "https://example.com/users")

        #expect(request.writtenAddress() == "https://example.com/users")
    }

    @Test("Query rows that are sent follow the template's own query and come before its fragment")
    func queryRows() {
        let request = ResolvedRequest(
            url: "https://example.com/users?sort=name#top",
            queryParameters: [
                KeyValue(key: "page size", value: "a&b"),
                KeyValue(key: "draft", value: "true", isEnabled: false),
                KeyValue(key: "", value: "no key")
            ]
        )

        #expect(request.writtenAddress() == "https://example.com/users?sort=name&page%20size=a%26b#top")
    }

    @Test("A variable left in a query row stays readable")
    func variableInQueryRow() {
        let request = ResolvedRequest(
            url: "https://example.com",
            queryParameters: [KeyValue(key: "key", value: "a {{token}}")]
        )

        #expect(request.writtenAddress() == "https://example.com?key=a%20{{token}}")
    }

    @Test("A path variable takes its row's value, and stays as written without a usable row")
    func pathVariables() {
        let request = ResolvedRequest(
            url: "https://example.com/:team/:user/:empty/:missing",
            pathParameters: [
                KeyValue(key: "team", value: "a/b"),
                KeyValue(key: "user", value: "42", isEnabled: false),
                KeyValue(key: "empty", value: "")
            ]
        )

        #expect(request.writtenAddress() == "https://example.com/a%2Fb/:user/:empty/:missing")
    }

    @Test("The segment after the scheme is the authority, so a port is never a path variable")
    func portIsNotAPathVariable() {
        let request = ResolvedRequest(
            url: "http://:8080/:8080",
            pathParameters: [KeyValue(key: "8080", value: "filled")]
        )

        #expect(request.writtenAddress() == "http://:8080/filled")
    }

    @Test(
        "A URL with no scheme gains the one sending adds, unless a variable may hold it",
        arguments: [
            ("localhost:8080/users", "http://localhost:8080/users"),
            ("example.com", "http://example.com"),
            ("{{host}}/users", "{{host}}/users"),
            ("", ""),
            ("  https://example.com  ", "https://example.com")
        ]
    )
    func scheme(written: String, expected: String) {
        #expect(ResolvedRequest(url: written).writtenAddress() == expected)
    }

    @Test("An added query pair stays as given, after the rows and before the fragment")
    func addedQuery() {
        let request = ResolvedRequest(
            url: "https://example.com#top",
            queryParameters: [KeyValue(key: "page", value: "2")]
        )

        #expect(request.writtenAddress(addingQuery: "key=<api-key>") == "https://example.com?page=2&key=<api-key>#top")
    }

}
