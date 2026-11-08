//  RequestSenderAuthorizationCodeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

struct RequestSenderAuthorizationCodeTests {

    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let accessToken = SecretReference(identifier: "access-token")
    static let issuedFor = "https://auth.example.com/token\nmoth\nread"
    nonisolated static let renewed = HTTPResponse(
        status: 200,
        headers: ["Content-Type": "application/json"],
        body: Data(#"{"access_token":"renewed","refresh_token":"r0tated","expires_in":3600}"#.utf8)
    )
    nonisolated static let accepted = HTTPResponse(status: 200, headers: [:], body: Data("ok".utf8))

    let secretStore = InMemorySecretStore()

    static let request = Request(
        name: "Me",
        urlTemplate: "https://api.example.com/me",
        auth: .oauth2(OAuth2Auth(
            grantType: .authorizationCodeWithPKCE,
            authorizationURL: "https://auth.example.com/authorize",
            accessTokenURL: "https://auth.example.com/token",
            callbackURL: "moth://oauth/callback",
            clientID: "moth",
            scope: "read",
            accessToken: accessToken
        ))
    )

    func send(_ transport: any HTTPTransport, at now: Date = Self.now) async -> SendResult {
        await RequestSender(transport: transport, secretStore: secretStore, now: { now })
            .send(OutgoingRequest(request: Self.request), scopes: VariableScopes())
    }

    func store(_ token: OAuth2Token) async {
        await secretStore.save(token.storedValue, for: Self.accessToken.identifier)
    }

    func storedToken() async -> OAuth2Token? {
        await secretStore.value(for: Self.accessToken.identifier).map(OAuth2Token.init(storedValue:))
    }

    static func token(secondsLeft: TimeInterval?, refreshToken: String? = "r3fresh") -> OAuth2Token {
        OAuth2Token(
            value: "stored",
            expiresAt: secondsLeft.map { now.addingTimeInterval($0) },
            issuedFor: issuedFor,
            refreshToken: refreshToken
        )
    }

    static func failure(_ error: OAuth2TokenError) -> SendResult {
        .failed(SendFailure(kind: .accessTokenFailed, description: error.localizedDescription), notes: [])
    }

    @Test(
        "A token with more than 60 seconds left is sent, and one with 60 or less is refreshed first",
        arguments: [(61.0, "Bearer stored", 1), (60.0, "Bearer renewed", 2)]
    )
    func refreshAtSend(secondsLeft: TimeInterval, expected: String, requests: Int) async {
        await store(Self.token(secondsLeft: secondsLeft))
        let transport = ScriptedTransport(Self.renewed, Self.accepted)

        _ = await send(transport)

        #expect(transport.requests.count == requests)
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == expected)
    }

    @Test("A refresh posts the refresh token to the Token URL and keeps the rotated one")
    func refreshStoresTheAnswer() async throws {
        await store(Self.token(secondsLeft: 30))
        let transport = ScriptedTransport(Self.renewed, Self.accepted)

        _ = await send(transport)

        let refresh = try #require(transport.requests.first)
        #expect(refresh.url?.absoluteString == "https://auth.example.com/token")
        #expect(refresh.httpBody == Data("grant_type=refresh_token&refresh_token=r3fresh&client_id=moth".utf8))
        #expect(await storedToken() == OAuth2Token(
            value: "renewed",
            expiresAt: Self.now.addingTimeInterval(3600),
            issuedFor: Self.issuedFor,
            refreshToken: "r0tated"
        ))
    }

    @Test("A refresh whose answer has no refresh token keeps the old one")
    func keepsTheOldRefreshToken() async {
        await store(Self.token(secondsLeft: 30))
        let transport = ScriptedTransport(
            HTTPResponse(status: 200, headers: [:], body: Data(#"{"access_token":"renewed"}"#.utf8)),
            Self.accepted
        )

        _ = await send(transport)

        #expect(await storedToken()?.refreshToken == "r3fresh")
        #expect(await storedToken()?.value == "renewed")
    }

    @Test("A refused refresh stops the send with Token Expired, and removes the refresh token")
    func refusedRefresh() async {
        await store(Self.token(secondsLeft: -5))
        let transport = ScriptedTransport(HTTPResponse(
            status: 400,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"error":"invalid_grant"}"#.utf8)
        ))

        let result = await send(transport)

        #expect(transport.requests.count == 1)
        #expect(result == Self.failure(.tokenExpired))
        #expect(await storedToken() == Self.token(secondsLeft: -5, refreshToken: nil))
    }

    @Test("A Token URL that can't be reached during a refresh keeps the refresh token")
    func unreachableRefresh() async {
        await store(Self.token(secondsLeft: -5))
        let transport = ScriptedTransport([{
            throw HTTPTransportError.connectionFailed(description: "Could not connect to the server.")
        }])

        let result = await send(transport)

        #expect(result == .failed(
            SendFailure(kind: .accessTokenFailed, description: "Could not connect to the server."),
            notes: []
        ))
        #expect(await storedToken() == Self.token(secondsLeft: -5))
    }

    @Test(
        "A token with no refresh token is sent until it expires, and then the send stops",
        arguments: [(30.0, true), (0.0, false)]
    )
    func noRefreshToken(secondsLeft: TimeInterval, isSent: Bool) async {
        await store(Self.token(secondsLeft: secondsLeft, refreshToken: nil))
        let transport = ScriptedTransport(Self.accepted)

        let result = await send(transport)

        #expect(transport.requests.count == (isSent ? 1 : 0))
        if !isSent {
            #expect(result == Self.failure(.tokenExpired))
        }
    }

    @Test("With no token, the send stops and asks for a new one, with no token request")
    func noToken() async {
        let transport = ScriptedTransport(Self.renewed, Self.accepted)

        let result = await send(transport)

        #expect(transport.requests.isEmpty)
        #expect(result == Self.failure(.signInNeeded))
    }

    @Test("A token issued for another Token URL is neither sent nor refreshed there")
    func otherFields() async {
        var token = Self.token(secondsLeft: 3600)
        token.issuedFor = "https://staging.example.com/token\nmoth\nread"
        await store(token)
        let transport = ScriptedTransport(Self.renewed, Self.accepted)

        let result = await send(transport)

        #expect(transport.requests.isEmpty)
        #expect(result == Self.failure(.issuedForOtherFields))
    }

}
