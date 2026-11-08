//  RequestSenderAuthorizationCodeTests+Recovery.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

extension RequestSenderAuthorizationCodeTests {

    nonisolated static func refusal(_ status: Int) -> HTTPResponse {
        HTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"error":"invalid_grant"}"#.utf8)
        )
    }

    @Test("A refused refresh drops the refresh token but still sends a token that hasn't expired")
    func refusedRefreshSendsAnUnexpiredToken() async {
        await store(Self.token(secondsLeft: 30))
        let transport = ScriptedTransport(Self.refusal(400), Self.accepted)

        _ = await send(transport)

        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer stored")
        #expect(await storedToken() == Self.token(secondsLeft: 30, refreshToken: nil))
    }

    @Test("A server error during a refresh isn't a refusal, so the refresh token is kept", arguments: [500, 503, 429])
    func serverErrorKeepsTheRefreshToken(status: Int) async {
        await store(Self.token(secondsLeft: -5))
        let transport = ScriptedTransport(Self.refusal(status))

        let result = await send(transport)

        #expect(result == Self.failure(.refused(status: status, error: "invalid_grant", description: nil)))
        #expect(await storedToken() == Self.token(secondsLeft: -5))
    }

    @Test("An unreachable Token URL during a refresh still sends a token that hasn't expired")
    func unreachableRefreshSendsAnUnexpiredToken() async {
        await store(Self.token(secondsLeft: 30))
        let transport = ScriptedTransport([
            { throw HTTPTransportError.connectionFailed(description: "Could not connect to the server.") },
            { Self.accepted }
        ])

        _ = await send(transport)

        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer stored")
        #expect(await storedToken() == Self.token(secondsLeft: 30))
    }

    @Test("A refusal after another send stored a newer token keeps and sends the newer one")
    func refusalKeepsANewerToken() async {
        await store(Self.token(secondsLeft: -5))
        let newer = OAuth2Token(
            value: "newer",
            expiresAt: Self.now.addingTimeInterval(3600),
            issuedFor: Self.issuedFor,
            refreshToken: "r0tated"
        )
        let secretStore = secretStore
        let transport = ScriptedTransport([
            {
                await secretStore.save(newer.storedValue, for: Self.accessToken.identifier)
                return Self.refusal(400)
            },
            { Self.accepted }
        ])

        _ = await send(transport)

        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer newer")
        #expect(await storedToken() == newer)
    }

    @Test("A Client Credentials token isn't sent under Authorization Code")
    func clientCredentialsTokenIsntSent() async {
        var token = Self.token(secondsLeft: 3600)
        token.issuedFor = "https://auth.example.com/token\nmoth\nread"
        await store(token)
        let transport = ScriptedTransport(Self.accepted)

        let result = await send(transport)

        #expect(transport.requests.isEmpty)
        #expect(result == Self.failure(.issuedForOtherFields))
    }

    @Test("Client Credentials replaces an Authorization Code token rather than sending it")
    func clientCredentialsReplacesAUsersToken() async {
        await store(Self.token(secondsLeft: 3600))
        guard case .oauth2(var oauth2) = Self.request.auth else {
            Issue.record("Expected OAuth 2.0")
            return
        }
        oauth2.grantType = .clientCredentials
        let request = Request(name: "Me", urlTemplate: "https://api.example.com/me", auth: .oauth2(oauth2))
        let transport = ScriptedTransport(Self.renewed, Self.accepted)
        let now = Self.now

        _ = await RequestSender(transport: transport, secretStore: secretStore, now: { now })
            .send(OutgoingRequest(request: request), scopes: VariableScopes())

        #expect(transport.requests.count == 2)
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer renewed")
    }

    @Test("An imported token, which records nothing it was issued for, is sent as it is")
    func importedTokenIsSent() async {
        await secretStore.save("imported-token", for: Self.accessToken.identifier)
        let transport = ScriptedTransport(Self.accepted)

        _ = await send(transport)

        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer imported-token")
    }

}
