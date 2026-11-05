//  URLSessionHTTPTransportTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

/// Serialized because StubURLProtocol's reply is process-wide.
@Suite(.serialized)
struct URLSessionHTTPTransportTests {

    private let request = URLRequest(url: URL(filePath: "/resource"))

    @Test("Sending a request returns the response's status, headers and body")
    func returnsTheResponse() async throws {
        let body = Data("{\"id\":1}".utf8)
        let session = StubURLProtocol.session(
            replying: .http(status: 201, headers: ["Content-Type": "application/json"], body: body)
        )
        let transport = URLSessionHTTPTransport(session: session)

        let response = try await transport.send(request)

        #expect(response.status == 201)
        #expect(response.headers == ["Content-Type": "application/json"])
        #expect(response.body == body)
    }

    @Test("The request reaches URLSession unchanged")
    func sendsTheRequest() async throws {
        let session = StubURLProtocol.session(replying: .http(status: 200, headers: [:], body: Data()))
        let transport = URLSessionHTTPTransport(session: session)
        var request = request
        request.httpMethod = "DELETE"
        request.setValue("Bearer token", forHTTPHeaderField: "Authorization")

        _ = try await transport.send(request)

        let received = try #require(StubURLProtocol.receivedRequests.first)
        #expect(received.httpMethod == "DELETE")
        #expect(received.url == request.url)
        #expect(received.value(forHTTPHeaderField: "Authorization") == "Bearer token")
    }

    @Test("A server error status is returned as a response, not thrown")
    func returnsAServerError() async throws {
        let session = StubURLProtocol.session(replying: .http(status: 500, headers: [:], body: Data("boom".utf8)))
        let transport = URLSessionHTTPTransport(session: session)

        let response = try await transport.send(request)

        #expect(response.status == 500)
        #expect(response.body == Data("boom".utf8))
    }

    @Test("An empty body comes back as empty data")
    func returnsAnEmptyBody() async throws {
        let session = StubURLProtocol.session(replying: .http(status: 204, headers: [:], body: Data()))
        let transport = URLSessionHTTPTransport(session: session)

        let response = try await transport.send(request)

        #expect(response.status == 204)
        #expect(response.body.isEmpty)
    }

    @Test("A connection failure surfaces as its URLError")
    func throwsAConnectionFailure() async {
        let session = StubURLProtocol.session(replying: .failure(URLError(.notConnectedToInternet)))
        let transport = URLSessionHTTPTransport(session: session)

        await #expect {
            try await transport.send(request)
        } throws: { error in
            (error as? URLError)?.code == .notConnectedToInternet
        }
    }

    @Test("A response that is not HTTP throws")
    func throwsForANonHTTPResponse() async {
        let session = StubURLProtocol.session(replying: .notHTTP(body: Data("file".utf8)))
        let transport = URLSessionHTTPTransport(session: session)

        await #expect(throws: HTTPTransportError.notHTTP) {
            try await transport.send(request)
        }
    }

}
