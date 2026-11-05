//  URLSessionLoopbackTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct URLSessionLoopbackTests {

    private static let hello = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
    private static let redirect = "HTTP/1.1 302 Found\r\nLocation: /final\r\nContent-Length: 0\r\n\r\n"
    private static let repeatedHeaders = [
        "HTTP/1.1 200 OK",
        "Set-Cookie: a=1",
        "Set-Cookie: b=2",
        "X-Tag: one",
        "X-Tag: two",
        "Content-Length: 0",
        "",
        ""
    ].joined(separator: "\r\n")

    private let session: URLSession
    private let transport: URLSessionHTTPTransport

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        self.transport = URLSessionHTTPTransport(session: session)
    }

    @Test("A real response reports its protocol, every byte of it, and no TLS phase over plain HTTP")
    func reportsTheProtocolAndBytes() async throws {
        let server = try await LoopbackServer(routes: ["/hello": Self.hello])

        let response = try await transport.send(URLRequest(url: server.url(path: "/hello")))

        let metrics = try #require(response.metrics)
        #expect(metrics.negotiatedProtocol == "http/1.1")
        #expect(metrics.bytesReceived == Self.hello.utf8.count)
        #expect(metrics.redirectCount == 0)
        #expect(metrics.connect != nil)
        #expect(metrics.tls == nil)
        #expect(metrics.firstByte != nil)
        #expect(metrics.download != nil)
    }

    @Test("A followed redirect is counted, and the bytes describe the final response")
    func countsARedirect() async throws {
        let server = try await LoopbackServer(routes: ["/start": Self.redirect, "/final": Self.hello])

        let response = try await transport.send(URLRequest(url: server.url(path: "/start")))

        #expect(response.status == 200)
        let metrics = try #require(response.metrics)
        #expect(metrics.redirectCount == 1)
        #expect(metrics.bytesReceived == Self.hello.utf8.count)
    }

    @Test("A second send on the same connection has no DNS or connect phase")
    func aReusedConnectionHasNoSetUpPhases() async throws {
        let server = try await LoopbackServer(routes: ["/hello": Self.hello])
        let request = try URLRequest(url: server.url(path: "/hello"))

        let first = try #require(await transport.send(request).metrics)
        let second = try #require(await transport.send(request).metrics)

        #expect(first.dns != nil)
        #expect(first.connect != nil)
        #expect(second.dns == nil)
        #expect(second.connect == nil)
        #expect(second.firstByte != nil)
    }

    @Test("URLSession merges a repeated header name, comma-separated, and that is what comes back")
    func recordsHowRepeatedHeadersComeBack() async throws {
        let server = try await LoopbackServer(routes: ["/headers": Self.repeatedHeaders])

        let response = try await transport.send(URLRequest(url: server.url(path: "/headers")))

        #expect(response.value(forHeader: "Set-Cookie") == "a=1, b=2")
        #expect(response.value(forHeader: "X-Tag") == "one, two")
    }

    @Test("A server that doesn't answer in time is a timeout, with the system's description")
    func aRealTimeout() async throws {
        let server = try await LoopbackServer(routes: [:])
        var request = try URLRequest(url: server.url(path: "/silent"))
        request.timeoutInterval = 0.2

        let error = try await thrownError(sending: request)

        #expect(try await error == .timedOut(description: systemDescription(sending: request)))
    }

    @Test("A refused connection is a connection failure, with the system's description")
    func aRealConnectionFailure() async throws {
        let request = try URLRequest(url: #require(URL(string: "http://127.0.0.1:1/")))

        let error = try await thrownError(sending: request)

        #expect(try await error == .connectionFailed(description: systemDescription(sending: request)))
    }

    @Test("HTTPS to a plain HTTP server is a TLS failure, with the system's description")
    func aRealTLSFailure() async throws {
        let server = try await LoopbackServer(routes: [:], fallback: Self.hello)

        let request = try URLRequest(url: server.url(path: "/hello", scheme: "https"))

        let error = try await thrownError(sending: request)

        #expect(try await error == .tlsFailed(description: systemDescription(sending: request)))
    }

    private func thrownError(sending request: URLRequest) async throws -> HTTPTransportError {
        try await #require(throws: HTTPTransportError.self) {
            try await transport.send(request)
        }
    }

    private func systemDescription(sending request: URLRequest) async throws -> String {
        let error = try await #require(throws: URLError.self) {
            try await session.data(for: request)
        }
        return error.localizedDescription
    }

}
