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
