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

    private let request: URLRequest
    private let systemDescription = [NSLocalizedDescriptionKey: "The system's words"]

    init() throws {
        self.request = try URLRequest(url: #require(URL(string: "https://example.test/resource")))
    }

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

    @Test("A response carries the URL URLSession says it came from, which is the last one after redirects")
    func returnsTheURL() async throws {
        let session = StubURLProtocol.session(replying: .http(status: 200, headers: [:], body: Data()))
        let transport = URLSessionHTTPTransport(session: session)

        let response = try await transport.send(request)

        #expect(response.url == request.url)
    }

    @Test("A response carries the metrics URLSession recorded for it")
    func returnsTheMetrics() async throws {
        let session = StubURLProtocol.session(replying: .http(status: 200, headers: [:], body: Data()))
        let transport = URLSessionHTTPTransport(session: session)

        let response = try await transport.send(request)

        let metrics = try #require(response.metrics)
        #expect(metrics.totalTime > .zero)
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

    @Test("A timeout surfaces as a timeout and keeps the system's description")
    func throwsATimeout() async throws {
        let error = try await thrownError(for: URLError(.timedOut, userInfo: systemDescription))

        #expect(error == .timedOut(description: "The system's words"))
    }

    @Test(
        "A connection failure surfaces as one and keeps the system's description",
        arguments: [
            URLError.Code.cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed,
            .notConnectedToInternet, .internationalRoamingOff, .callIsActive, .dataNotAllowed
        ]
    )
    func throwsAConnectionFailure(code: URLError.Code) async throws {
        let error = try await thrownError(for: URLError(code, userInfo: systemDescription))

        #expect(error == .connectionFailed(description: "The system's words"))
    }

    @Test(
        "A TLS failure surfaces as one and keeps the system's description",
        arguments: [
            URLError.Code.secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
            .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .clientCertificateRejected,
            .clientCertificateRequired
        ]
    )
    func throwsATLSFailure(code: URLError.Code) async throws {
        let error = try await thrownError(for: URLError(code, userInfo: systemDescription))

        #expect(error == .tlsFailed(description: "The system's words"))
    }

    @Test("A URLError of no particular kind surfaces as a failure, so none reaches the app")
    func throwsAnUnclassifiedURLError() async throws {
        let error = try await thrownError(for: URLError(.badServerResponse, userInfo: systemDescription))

        #expect(error == .failed(description: "The system's words"))
    }

    @Test("An error that is not a URLError surfaces as a failure")
    func throwsAFailureForOtherErrors() async throws {
        let error = try await thrownError(for: NSError(domain: "Other", code: 1, userInfo: systemDescription))

        #expect(error == .failed(description: "The system's words"))
    }

    @Test("Cancelling a send in flight surfaces as a cancellation", .timeLimit(.minutes(1)))
    func throwsACancellationWhenCancelledInFlight() async {
        let session = StubURLProtocol.session(replying: .neverFinishes)
        let transport = URLSessionHTTPTransport(session: session)
        let request = request

        let send = Task { try await transport.send(request) }
        for await _ in StubURLProtocol.loadsStarted {
            break
        }
        send.cancel()

        await #expect(throws: CancellationError.self) {
            try await send.value
        }
    }

    @Test("A send cancelled before it starts surfaces as a cancellation")
    func throwsACancellationWhenAlreadyCancelled() async {
        let session = StubURLProtocol.session(replying: .http(status: 200, headers: [:], body: Data()))
        let transport = URLSessionHTTPTransport(session: session)
        let request = request

        let send = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await transport.send(request)
        }

        await #expect(throws: CancellationError.self) {
            try await send.value
        }
    }

    @Test("A task URLSession cancelled surfaces as a cancellation, though no Swift task was cancelled")
    func throwsACancellationForURLSessionsOwnCancel() async {
        let session = StubURLProtocol.session(replying: .failure(URLError(.cancelled)))
        let transport = URLSessionHTTPTransport(session: session)

        await #expect(throws: CancellationError.self) {
            try await transport.send(request)
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

    private func thrownError(for failure: any Error) async throws -> HTTPTransportError {
        let session = StubURLProtocol.session(replying: .failure(failure))
        let transport = URLSessionHTTPTransport(session: session)

        return try await #require(throws: HTTPTransportError.self) {
            try await transport.send(request)
        }
    }

}
