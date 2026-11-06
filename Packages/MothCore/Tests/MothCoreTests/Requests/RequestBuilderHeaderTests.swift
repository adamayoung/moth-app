//  RequestBuilderHeaderTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import MothCore
import Testing

struct RequestBuilderHeaderTests {

    private let builder = RequestBuilder()

    @Test("The method is applied, as written")
    func method() async throws {
        let built = try await builder.build(
            ResolvedRequest(method: HTTPMethod(rawValue: "PROPFIND"), url: "https://example.com")
        )

        #expect(built.urlRequest.httpMethod == "PROPFIND")
    }

    @Test("A method that is not an HTTP token is an error", arguments: ["", "GET X", "GET\r\nX: y"])
    func invalidMethod(method: String) async {
        await #expect(throws: RequestBuildError.invalidMethod) {
            try await builder.build(ResolvedRequest(method: HTTPMethod(rawValue: method), url: "https://example.com"))
        }
    }

    @Test("The method error reads as the app shows it")
    func invalidMethodDescription() {
        #expect(RequestBuildError.invalidMethod.errorDescription == "This method isn’t valid.")
    }

    @Test(
        "A header URLSession would drop, strip or send raw is left out and reported",
        arguments: [
            ("X-Name", "日本"),
            ("X-Name", "a🙂"),
            ("X-Name", "abc\n"),
            ("X Name", "value"),
            ("X\nName", "value")
        ]
    )
    func unsendableHeader(name: String, value: String) async throws {
        let built = try await builder.build(
            ResolvedRequest(url: "https://example.com", headers: [KeyValue(key: name, value: value)])
        )

        #expect(built.urlRequest.allHTTPHeaderFields?.isEmpty != false)
        #expect(built.notices == [.unsendableHeader(name: name)])
    }

    @Test("A Latin-1 header value is sent")
    func latin1Header() async throws {
        let built = try await builder.build(
            ResolvedRequest(url: "https://example.com", headers: [KeyValue(key: "X-Name", value: "café")])
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Name") == "café")
        #expect(built.notices.isEmpty)
    }

    @Test("Repeated Cookie headers join as RFC 6265 requires, in any case")
    func repeatedCookies() async throws {
        let built = try await builder.build(
            ResolvedRequest(
                url: "https://example.com",
                headers: [KeyValue(key: "Cookie", value: "a=1"), KeyValue(key: "cookie", value: "b=2")]
            )
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "Cookie") == "a=1; b=2")
    }

    @Test("Enabled headers are sent, and disabled or nameless ones are not")
    func enabledHeaders() async throws {
        let built = try await builder.build(
            ResolvedRequest(
                url: "https://example.com",
                headers: [
                    KeyValue(key: "Accept", value: "application/json"),
                    KeyValue(key: "X-Draft", value: "true", isEnabled: false),
                    KeyValue(key: "", value: "orphan")
                ]
            )
        )

        #expect(built.urlRequest.allHTTPHeaderFields == ["Accept": "application/json"])
    }

    @Test("Repeated header names are kept in order, in any case")
    func repeatedHeaders() async throws {
        let built = try await builder.build(
            ResolvedRequest(
                url: "https://example.com",
                headers: [KeyValue(key: "X-Tag", value: "a"), KeyValue(key: "x-tag", value: "b")]
            )
        )

        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Tag") == "a,b")
    }

    @Test("The timeout is applied", arguments: [(Duration.seconds(30), 30.0), (.milliseconds(1500), 1.5)])
    func timeout(timeout: Duration, expected: TimeInterval) async throws {
        let built = try await builder.build(
            ResolvedRequest(url: "https://example.com", settings: RequestSettings(timeout: timeout))
        )

        #expect(built.urlRequest.timeoutInterval == expected)
    }

}
