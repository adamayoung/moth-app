//  OAuth2TokenRequestGrantTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

struct OAuth2TokenRequestGrantTests {

    private static let exchangeForm =
        "grant_type=authorization_code&code=c0de&redirect_uri=moth%3A%2F%2Foauth%2Fcallback&code_verifier=v3rifier"

    private static func request(
        clientSecret: String = "s3cret",
        grant: OAuth2TokenRequest.Grant
    ) -> OAuth2TokenRequest {
        OAuth2TokenRequest(
            tokenURL: "https://auth.example.com/token",
            clientID: "moth app",
            clientSecret: clientSecret,
            scope: "read",
            grant: grant
        )
    }

    private static let exchange = OAuth2TokenRequest.Grant.authorizationCode(
        code: "c0de",
        redirectURI: "moth://oauth/callback",
        verifier: "v3rifier"
    )

    @Test("The code exchange posts the code, the callback and the verifier, with no scope")
    func exchangeForm() throws {
        let urlRequest = try Self.request(grant: Self.exchange).urlRequest(timeout: .seconds(30))

        #expect(urlRequest.httpMethod == "POST")
        #expect(urlRequest.httpBody == Data(Self.exchangeForm.utf8))
        #expect(
            urlRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("moth%20app:s3cret".utf8).base64EncodedString())"
        )
    }

    @Test("With an empty Client Secret, the client goes in the body and no credentials are sent")
    func publicClient() throws {
        let urlRequest = try Self.request(clientSecret: "", grant: Self.exchange).urlRequest(timeout: .seconds(30))

        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(urlRequest.httpBody == Data((Self.exchangeForm + "&client_id=moth%20app").utf8))
    }

    @Test("A refresh posts the refresh token")
    func refreshForm() throws {
        let urlRequest = try Self.request(grant: .refreshToken("r3fresh")).urlRequest(timeout: .seconds(30))

        #expect(urlRequest.httpBody == Data("grant_type=refresh_token&refresh_token=r3fresh".utf8))
        #expect(urlRequest.value(forHTTPHeaderField: "Authorization") != nil)
    }

    @Test("Client Credentials keeps its Basic header with an empty Client Secret")
    func clientCredentialsUnchanged() throws {
        let urlRequest = try Self.request(clientSecret: "", grant: .clientCredentials).urlRequest(timeout: .seconds(30))

        #expect(
            urlRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("moth%20app:".utf8).base64EncodedString())"
        )
        #expect(urlRequest.httpBody == Data("grant_type=client_credentials&scope=read".utf8))
    }

    @Test("An answer's refresh token is read")
    func readsTheRefreshToken() throws {
        let response = HTTPResponse(
            status: 200,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"access_token":"a","refresh_token":"r","expires_in":60}"#.utf8)
        )

        let token = try OAuth2TokenRequest.token(from: response, receivedAt: Date(timeIntervalSince1970: 0))

        #expect(token.refreshToken == "r")
    }
}
