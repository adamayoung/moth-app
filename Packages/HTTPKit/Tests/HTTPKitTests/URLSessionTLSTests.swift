//  URLSessionTLSTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

/// Over a real TLS socket whose certificate nothing trusts.
struct URLSessionTLSTests {

    private static let hello = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"

    private let transport = URLSessionHTTPTransport(
        session: URLSession(configuration: URLSessionHTTPTransport.sessionConfiguration)
    )

    private func server() async throws -> LoopbackServer {
        try await LoopbackServer(routes: [:], fallback: Self.hello, identity: LoopbackIdentity.make())
    }

    @Test("With verification on, an untrusted certificate fails the send as a TLS failure")
    func verifiedFails() async throws {
        let server = try await server()
        let request = try URLRequest(url: server.url(path: "/hello", scheme: "https"))

        let error = await #expect(throws: HTTPTransportError.self) {
            try await transport.send(request, cookies: nil, policy: SendPolicy(verifiesTLS: true))
        }

        #expect(error.map(Self.isTLSFailure) == true)
    }

    @Test("With verification off, the same request succeeds")
    func unverifiedSucceeds() async throws {
        let server = try await server()
        let request = try URLRequest(url: server.url(path: "/hello", scheme: "https"))

        let response = try await transport.send(request, cookies: nil, policy: SendPolicy(verifiesTLS: false))

        #expect(response.status == 200)
        #expect(response.body == Data("hello".utf8))
    }

    @Test("With verification on, a send straight after one with it off, to the same server, still fails")
    func verificationIsPerSend() async throws {
        let server = try await server()
        let request = try URLRequest(url: server.url(path: "/hello", scheme: "https"))

        _ = try await transport.send(request, cookies: nil, policy: SendPolicy(verifiesTLS: false))
        let error = await #expect(throws: HTTPTransportError.self) {
            try await transport.send(request, cookies: nil, policy: SendPolicy(verifiesTLS: true))
        }

        #expect(error.map(Self.isTLSFailure) == true)
    }

    private static func isTLSFailure(_ error: HTTPTransportError) -> Bool {
        if case .tlsFailed = error {
            return true
        }
        return false
    }

}
