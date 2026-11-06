//  StubHTTPTransportTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import Moth
import Testing

struct StubHTTPTransportTests {

    private func request(_ address: String) throws -> URLRequest {
        try URLRequest(url: #require(URL(string: address)))
    }

    @Test("A request to an unroutable host gets the fixed response, so nothing reached the network")
    func answersWithoutTheNetwork() async throws {
        let response = try await StubHTTPTransport().send(request("https://stub.invalid/"))

        #expect(response.status == 200)
        #expect(response.value(forHeader: "Content-Type") == "application/json")
        #expect(response.body == Data(#"{"id":1,"name":"Moth"}"#.utf8))
    }

    @Test("The fixed response has metrics with a phase that didn't happen, for the Timing tab")
    func hasMetrics() async throws {
        let response = try await StubHTTPTransport().send(request("https://stub.invalid/"))

        let metrics = try #require(response.metrics)
        #expect(metrics.totalTime == .milliseconds(142))
        #expect(metrics.dns != nil)
        #expect(metrics.tls == nil)
    }

    @Test("/wait stays in flight until it is cancelled")
    func waitsForCancellation() async throws {
        let request = try request("https://stub.invalid/wait")
        let send = Task { try await StubHTTPTransport().send(request) }

        send.cancel()

        await #expect(throws: CancellationError.self) {
            try await send.value
        }
    }

    @Test("/refused fails to connect")
    func refused() async throws {
        let request = try request("https://stub.invalid/refused")

        await #expect(throws: HTTPTransportError.self) {
            try await StubHTTPTransport().send(request)
        }
    }

    @Test("/timeout times out")
    func timesOut() async throws {
        let request = try request("https://stub.invalid/timeout")

        await #expect {
            try await StubHTTPTransport().send(request)
        } throws: { error in
            guard case .timedOut = error as? HTTPTransportError else {
                return false
            }
            return true
        }
    }

}
