//  OAuth2TokenRequestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

struct OAuth2TokenRequestTests {

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func request(
        tokenURL: String = "https://auth.example.com/token",
        clientID: String = "moth",
        clientSecret: String = "s3cret",
        scope: String = ""
    ) -> OAuth2TokenRequest {
        OAuth2TokenRequest(tokenURL: tokenURL, clientID: clientID, clientSecret: clientSecret, scope: scope)
    }

    private static func answer(_ status: Int, _ json: String) -> HTTPResponse {
        HTTPResponse(status: status, headers: ["Content-Type": "application/json"], body: Data(json.utf8))
    }

    @Test("The token request posts the client credentials grant as a form")
    func postsTheGrant() throws {
        let urlRequest = try Self.request().urlRequest(timeout: .seconds(30))

        #expect(urlRequest.url?.absoluteString == "https://auth.example.com/token")
        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/x-www-form-urlencoded")
        #expect(urlRequest.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(urlRequest.httpBody == Data("grant_type=client_credentials".utf8))
        #expect(urlRequest.timeoutInterval == 30)
    }

    @Test("A scope is sent form-encoded")
    func sendsScope() throws {
        let urlRequest = try Self.request(scope: "read write").urlRequest(timeout: .seconds(30))

        #expect(urlRequest.httpBody == Data("grant_type=client_credentials&scope=read%20write".utf8))
    }

    @Test("The client credentials go in a Basic header, each form-encoded first, as RFC 6749 section 2.3.1 says")
    func basicHeader() throws {
        let urlRequest = try Self.request(clientID: "moth app", clientSecret: "a:b%c").urlRequest(timeout: .seconds(30))
        let expected = Data("moth%20app:a%3Ab%25c".utf8).base64EncodedString()

        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == "Basic \(expected)")
    }

    @Test("A Token URL that isn't an http URL is refused", arguments: ["", "not a url", "ftp://example.com/token"])
    func invalidTokenURL(tokenURL: String) {
        #expect(throws: OAuth2TokenError.invalidTokenURL) {
            try Self.request(tokenURL: tokenURL).urlRequest(timeout: .seconds(30))
        }
    }

    @Test("An answer with expires_in expires that many seconds after it arrived")
    func expiresIn() throws {
        let token = try OAuth2TokenRequest.token(
            from: Self.answer(200, #"{"access_token":"abc","token_type":"Bearer","expires_in":3600}"#),
            receivedAt: Self.now
        )

        #expect(token == OAuth2Token(value: "abc", expiresAt: Self.now.addingTimeInterval(3600)))
    }

    @Test("An expires_in sent as a string is read too")
    func expiresInAsString() throws {
        let token = try OAuth2TokenRequest.token(
            from: Self.answer(200, #"{"access_token":"abc","expires_in":"60"}"#),
            receivedAt: Self.now
        )

        #expect(token.expiresAt == Self.now.addingTimeInterval(60))
    }

    @Test("An answer with no expires_in has no expiry")
    func noExpiresIn() throws {
        let token = try OAuth2TokenRequest.token(
            from: Self.answer(200, #"{"access_token":"abc"}"#),
            receivedAt: Self.now
        )

        #expect(token == OAuth2Token(value: "abc", expiresAt: nil))
    }

    @Test("A success with no access token is an error")
    func noAccessToken() {
        #expect(throws: OAuth2TokenError.noAccessToken) {
            try OAuth2TokenRequest.token(from: Self.answer(200, #"{"token_type":"Bearer"}"#), receivedAt: Self.now)
        }
    }

    @Test("A refusal carries the server's error and description")
    func refusal() throws {
        let error = try #require(throws: OAuth2TokenError.self) {
            try OAuth2TokenRequest.token(
                from: Self.answer(401, #"{"error":"invalid_client","error_description":"Unknown client."}"#),
                receivedAt: Self.now
            )
        }

        #expect(error == .refused(status: 401, error: "invalid_client", description: "Unknown client."))
        #expect(error.errorDescription == "invalid_client: Unknown client.")
    }

    @Test("A refusal with only an error code shows the code")
    func refusalWithoutDescription() {
        let error = OAuth2TokenError.refused(status: 400, error: "invalid_scope", description: nil)

        #expect(error.errorDescription == "invalid_scope")
    }

    @Test("A refusal with no JSON names the status")
    func refusalWithoutJSON() throws {
        let error = try #require(throws: OAuth2TokenError.self) {
            try OAuth2TokenRequest.token(
                from: HTTPResponse(status: 500, headers: [:], body: Data("Bad gateway".utf8)),
                receivedAt: Self.now
            )
        }

        #expect(error == .refused(status: 500, error: nil, description: nil))
        #expect(error.errorDescription == "The token endpoint answered 500.")
    }

}
