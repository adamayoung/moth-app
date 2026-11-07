//  RequestSenderOAuth2Tests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

struct RequestSenderOAuth2Tests {

    private static let now = Date(timeIntervalSince1970: 1_800_000_000)
    private static let clientSecret = SecretReference(identifier: "client-secret")
    private static let accessToken = SecretReference(identifier: "access-token")
    private nonisolated static let issued = HTTPResponse(
        status: 200,
        headers: ["Content-Type": "application/json"],
        body: Data(#"{"access_token":"issued-tok","token_type":"Bearer","expires_in":3600}"#.utf8)
    )
    private nonisolated static let accepted = HTTPResponse(status: 200, headers: [:], body: Data("ok".utf8))

    private let secretStore = InMemorySecretStore()

    private static func oauth2(
        tokenURL: String = "https://auth.example.com/token",
        clientID: String = "moth",
        scope: String = "",
        accessToken: SecretReference? = accessToken
    ) -> Auth {
        .oauth2(OAuth2Auth(
            grantType: .clientCredentials,
            authorizationURL: "",
            accessTokenURL: tokenURL,
            callbackURL: "",
            clientID: clientID,
            clientSecret: clientSecret,
            scope: scope,
            accessToken: accessToken
        ))
    }

    private static func request(auth: Auth = oauth2()) -> Request {
        Request(name: "List", urlTemplate: "https://api.example.com/users", auth: auth)
    }

    private func sender(_ transport: any HTTPTransport, at now: Date = Self.now) -> RequestSender {
        RequestSender(transport: transport, secretStore: secretStore, now: { now })
    }

    private func store(_ token: OAuth2Token) async {
        await secretStore.save(token.storedValue, for: Self.accessToken.identifier)
    }

    private func storedToken() async -> OAuth2Token? {
        await secretStore.value(for: Self.accessToken.identifier).map(OAuth2Token.init(storedValue:))
    }

    init() async {
        await secretStore.save("s3cret", for: Self.clientSecret.identifier)
    }

    @Test("A stored token goes out as a Bearer header, with no token request")
    func storedTokenIsSent() async {
        await store(OAuth2Token(value: "stored", expiresAt: Self.now.addingTimeInterval(3600)))
        let transport = ScriptedTransport(Self.accepted)

        _ = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(transport.requests.map(\.url?.host) == ["api.example.com"])
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer stored")
    }

    @Test("With no token, a send gets one first, stores it, and sends it")
    func noTokenGetsOne() async throws {
        let transport = ScriptedTransport(Self.issued, Self.accepted)

        _ = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        let tokenRequest = try #require(transport.requests.first)
        #expect(transport.requests.count == 2)
        #expect(tokenRequest.url?.absoluteString == "https://auth.example.com/token")
        #expect(tokenRequest.httpBody == Data("grant_type=client_credentials".utf8))
        #expect(
            tokenRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("moth:s3cret".utf8).base64EncodedString())"
        )
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer issued-tok")
        #expect(await storedToken() == OAuth2Token(value: "issued-tok", expiresAt: Self.now.addingTimeInterval(3600)))
    }

    @Test(
        "A token with more than 60 seconds left is reused, and one with 60 or less is replaced",
        arguments: [(61.0, "Bearer stored"), (60.0, "Bearer issued-tok")]
    )
    func renewalEdge(secondsLeft: TimeInterval, expected: String) async {
        await store(OAuth2Token(value: "stored", expiresAt: Self.now.addingTimeInterval(secondsLeft)))
        let transport = ScriptedTransport(Self.issued, Self.accepted)

        _ = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == expected)
    }

    @Test("A token with no expiry is used until it is cleared")
    func noExpiryIsReused() async {
        await store(OAuth2Token(value: "stored", expiresAt: nil))
        let transport = ScriptedTransport(Self.accepted)
        let later = Self.now.addingTimeInterval(365 * 86400)

        _ = await sender(transport, at: later).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(transport.requests.count == 1)
        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer stored")
    }

    @Test("A refused token request stops the send, and the failure carries the server's error")
    func refusalStopsTheSend() async {
        let transport = ScriptedTransport(HTTPResponse(
            status: 401,
            headers: ["Content-Type": "application/json"],
            body: Data(#"{"error":"invalid_client","error_description":"Unknown client."}"#.utf8)
        ))

        let result = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(transport.requests.count == 1)
        #expect(result == .failed(
            SendFailure(kind: .accessTokenFailed, description: "invalid_client: Unknown client."),
            notes: []
        ))
        #expect(await storedToken() == nil)
    }

    @Test("A token URL that can't be reached stops the send with the transport's message")
    func unreachableTokenURL() async {
        let transport = ScriptedTransport([{
            throw HTTPTransportError.connectionFailed(description: "Could not connect to the server.")
        }])

        let result = await sender(transport).send(OutgoingRequest(request: Self.request()), scopes: VariableScopes())

        #expect(result == .failed(
            SendFailure(kind: .accessTokenFailed, description: "Could not connect to the server."),
            notes: []
        ))
    }

    @Test("A send cancelled while getting a token is cancelled, not failed")
    func cancelledWhileGettingAToken() async {
        let transport = ScriptedTransport([{
            try await Task.sleep(for: .seconds(600))
            return Self.issued
        }])
        let sender = sender(transport)

        let send = Task { await sender.send(OutgoingRequest(request: Self.request()), scopes: VariableScopes()) }
        for await _ in transport.arrivals {
            break
        }
        send.cancel()

        #expect(await send.value == .cancelled)
    }

    @Test("Variables resolve in the Token URL, Client ID, Scope and Client Secret")
    func variablesResolve() async throws {
        await secretStore.save("{{secret}}", for: Self.clientSecret.identifier)
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        let request = Self.request(auth: Self.oauth2(
            tokenURL: "{{authHost}}/token",
            clientID: "{{client}}",
            scope: "{{scope}}"
        ))
        let scopes = VariableScopes(environment: [
            Variable(name: "authHost", value: .plain(initial: "", current: "https://login.example.com")),
            Variable(name: "client", value: .plain(initial: "", current: "env-client")),
            Variable(name: "scope", value: .plain(initial: "", current: "read")),
            Variable(name: "secret", value: .plain(initial: "", current: "env-secret"))
        ])

        _ = await sender(transport).send(OutgoingRequest(request: request), scopes: scopes)

        let tokenRequest = try #require(transport.requests.first)
        #expect(tokenRequest.url?.absoluteString == "https://login.example.com/token")
        #expect(tokenRequest.httpBody == Data("grant_type=client_credentials&scope=read".utf8))
        #expect(
            tokenRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("env-client:env-secret".utf8).base64EncodedString())"
        )
    }

    @Test("A Client Secret typed and not yet saved is the one the token request sends")
    func typedSecretIsSent() async throws {
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        let typed = [CredentialWrite(reference: Self.clientSecret, value: "typed")]

        _ = await sender(transport).send(
            OutgoingRequest(request: Self.request(), typedCredentials: typed),
            scopes: VariableScopes()
        )

        let tokenRequest = try #require(transport.requests.first)
        #expect(
            tokenRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("moth:typed".utf8).base64EncodedString())"
        )
    }

    @Test("Two requests inheriting one auth share its token")
    func inheritedAuthSharesAToken() async {
        let first = Request(name: "First", urlTemplate: "https://api.example.com/a")
        let second = Request(name: "Second", urlTemplate: "https://api.example.com/b")
        let collection = RequestCollection(
            name: "API",
            auth: Self.oauth2(),
            children: [
                CollectionItem(sortOrder: 0, node: .request(first)),
                CollectionItem(sortOrder: 1, node: .request(second))
            ]
        )
        let transport = ScriptedTransport(Self.issued, Self.accepted)
        let sender = sender(transport)

        for request in [first, second] {
            var sent = request
            sent.auth = collection.effectiveAuth(of: request)
            _ = await sender.send(OutgoingRequest(request: sent), scopes: VariableScopes())
        }

        #expect(transport.requests.map { $0.url?.path() } == ["/token", "/a", "/b"])
        #expect(transport.requests.dropFirst().map { $0.value(forHTTPHeaderField: "Authorization") } == [
            "Bearer issued-tok",
            "Bearer issued-tok"
        ])
    }

    @Test("An auth with no token reference gets a token for each send and stores nothing")
    func noReferenceStoresNothing() async {
        let transport = ScriptedTransport(Self.issued, Self.accepted, Self.issued, Self.accepted)
        let request = Self.request(auth: Self.oauth2(accessToken: nil))

        _ = await sender(transport).send(OutgoingRequest(request: request), scopes: VariableScopes())
        _ = await sender(transport).send(OutgoingRequest(request: request), scopes: VariableScopes())

        #expect(transport.requests.map { $0.url?.path() } == ["/token", "/users", "/token", "/users"])
        #expect(transport.requests.last?.value(forHTTPHeaderField: "Authorization") == "Bearer issued-tok")
    }

    @Test("Neither the token nor the client secret reaches History or the request it records")
    func noSecretInHistory() async throws {
        let transport = ScriptedTransport(Self.issued, Self.accepted)

        let recorded = await sender(transport).sendRecording(
            OutgoingRequest(request: Self.request()),
            scopes: VariableScopes()
        )

        let entry = try #require(recorded.entry)
        let encoded = try #require(String(bytes: JSONEncoder().encode(entry.request), encoding: .utf8))
        #expect(!encoded.contains("issued-tok"))
        #expect(!encoded.contains("s3cret"))
        #expect(!String(describing: entry).contains("issued-tok"))
        #expect(!String(describing: entry).contains("s3cret"))
    }

    @Test("Send Again with a masked Authorization row under Client Credentials sends, because the token replaces it")
    func sendAgainReplacesAMaskedAuthorization() async {
        await store(OAuth2Token(value: "stored", expiresAt: nil))
        let transport = ScriptedTransport(Self.accepted)
        var request = Self.request()
        request.headers = [KeyValue(key: "Authorization", value: HistoryEntry.maskedValue)]

        let outcome = await sender(transport).sendAgain(HistoryEntry(
            request: request,
            sentAt: Self.now,
            duration: .zero
        ))

        #expect(outcome != .secretUnavailable)
        #expect(transport.requests.map { $0.value(forHTTPHeaderField: "Authorization") } == ["Bearer stored"])
    }

}
