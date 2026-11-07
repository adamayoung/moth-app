//  StubHTTPTransport.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// Routes by path, so a UI test reaches each case by typing a URL, with no launch argument.
final nonisolated class StubHTTPTransport: HTTPTransport {

    private static let body = Data(#"{"id":1,"name":"Moth"}"#.utf8)
    private static let headers = ["Content-Type": "application/json", "X-Request-Id": "stub"]

    /// `tls` stays nil, so a test can prove the Timing tab lists only the phases that happened.
    private static let metrics = HTTPMetrics(
        totalTime: .milliseconds(142),
        dns: .milliseconds(12),
        connect: .milliseconds(30),
        firstByte: .milliseconds(90),
        download: .milliseconds(10)
    )

    private static let digestChallenge = [
        "WWW-Authenticate": #"Digest realm="stub", nonce="stub-nonce", qop="auth", algorithm=SHA-256"#
    ]

    /// One per token state the OAuth 2.0 pane shows: expiring, expired, with no expiry, and refused.
    private static let tokenAnswers = [
        "/token": (200, #"{"access_token":"stub-access-token","expires_in":3600,"token_type":"Bearer"}"#),
        "/token/expired": (200, #"{"access_token":"stub-access-token","expires_in":0,"token_type":"Bearer"}"#),
        "/token/forever": (200, #"{"access_token":"stub-access-token","token_type":"Bearer"}"#),
        "/token/refused": (401, #"{"error":"invalid_client","error_description":"Client authentication failed."}"#)
    ]

    @concurrent
    func send(_ request: URLRequest, cookies _: any CookieJar?, policy _: SendPolicy) async throws -> HTTPResponse {
        if let path = request.url?.path(), let (status, body) = Self.tokenAnswers[path] {
            return HTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: Data(body.utf8))
        }
        switch request.url?.path() {
        case "/digest" where request.value(forHTTPHeaderField: "Authorization") == nil:
            return HTTPResponse(status: 401, headers: Self.digestChallenge, body: Data())
        case "/wait":
            try await Task.sleep(for: .seconds(600))
        case "/refused":
            throw HTTPTransportError.connectionFailed(description: "Could not connect to the server.")
        case "/timeout":
            throw HTTPTransportError.timedOut(description: "The request timed out.")
        default:
            break
        }
        return HTTPResponse(status: 200, headers: Self.headers, body: Self.body, metrics: Self.metrics)
    }

}
