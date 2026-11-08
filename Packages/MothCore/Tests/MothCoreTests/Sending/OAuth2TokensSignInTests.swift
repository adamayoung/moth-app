//  OAuth2TokensSignInTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
@testable import MothCore
import Testing

/// A sign-in sheet that records where it was opened and answers with a callback it builds from that URL.
@MainActor
final class FakeSignIn {

    private(set) var opened: [(url: URL, callbackScheme: String)] = []
    var answer: (URL) throws -> URL

    init(answer: @escaping (URL) throws -> URL = FakeSignIn.approve) {
        self.answer = answer
    }

    var signIn: OAuth2SignIn {
        { url, callbackScheme in
            self.opened.append((url, callbackScheme))
            return try self.answer(url)
        }
    }

    nonisolated static func approve(_ url: URL) throws -> URL {
        try callback("code=c0de&state=\(query(of: url)["state"] ?? "")")
    }

    nonisolated static func callback(_ query: String) throws -> URL {
        try #require(URL(string: "moth://oauth/callback?\(query)"))
    }

    nonisolated static func query(of url: URL) -> [String: String] {
        fields(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
    }

    nonisolated static func form(of request: URLRequest?) -> [String: String] {
        var components = URLComponents()
        components.percentEncodedQuery = request?.httpBody.flatMap { String(bytes: $0, encoding: .utf8) }
        return fields(components.queryItems ?? [])
    }

    private nonisolated static func fields(_ items: [URLQueryItem]) -> [String: String] {
        Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

}

@MainActor
struct OAuth2TokensSignInTests {

    nonisolated static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let clientSecret = SecretReference(identifier: "client-secret")
    static let accessToken = SecretReference(identifier: "access-token")
    nonisolated static let issued = HTTPResponse(
        status: 200,
        headers: ["Content-Type": "application/json"],
        body: Data(#"{"access_token":"acc3ss","refresh_token":"r3fresh","expires_in":3600}"#.utf8)
    )

    let secretStore = InMemorySecretStore()

    init() async {
        await secretStore.save("s3cret", for: Self.clientSecret.identifier)
    }

    static func outgoing(
        callbackURL: String = "moth://oauth/callback",
        clientSecret: SecretReference? = clientSecret
    ) -> OutgoingRequest {
        OutgoingRequest(request: Request(
            name: "Me",
            urlTemplate: "https://api.example.com/me",
            auth: .oauth2(OAuth2Auth(
                grantType: .authorizationCodeWithPKCE,
                authorizationURL: "https://auth.example.com/authorize",
                accessTokenURL: "https://auth.example.com/token",
                callbackURL: callbackURL,
                clientID: "moth",
                clientSecret: clientSecret,
                scope: "read",
                accessToken: accessToken
            ))
        ))
    }

    func tokens(_ transport: any HTTPTransport) -> OAuth2Tokens {
        OAuth2Tokens(transport: transport, secretStore: secretStore, now: { Self.now })
    }

    func storedToken() async -> OAuth2Token? {
        await secretStore.value(for: Self.accessToken.identifier).map(OAuth2Token.init(storedValue:))
    }

    @Test("Get New Access Token opens the sign-in at the Auth URL, waiting on the Callback URL's scheme")
    func opensTheSignIn() async throws {
        let signIn = FakeSignIn()

        _ = try await tokens(ScriptedTransport(Self.issued))
            .getNewToken(for: Self.outgoing(), scopes: VariableScopes(), signIn: signIn.signIn)

        let opened = try #require(signIn.opened.first)
        let query = FakeSignIn.query(of: opened.url)
        #expect(signIn.opened.count == 1)
        #expect(opened.callbackScheme == "moth")
        #expect(opened.url.host() == "auth.example.com")
        #expect(query["response_type"] == "code")
        #expect(query["client_id"] == "moth")
        #expect(query["redirect_uri"] == "moth://oauth/callback")
        #expect(query["scope"] == "read")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["state"]?.count == 43)
        #expect(query["code_challenge"]?.count == 43)
    }

    @Test("Each sign-in has a fresh state and verifier")
    func freshStateAndVerifier() async throws {
        let signIn = FakeSignIn()
        let tokens = tokens(ScriptedTransport(Self.issued, Self.issued))

        _ = try await tokens.getNewToken(for: Self.outgoing(), scopes: VariableScopes(), signIn: signIn.signIn)
        _ = try await tokens.getNewToken(for: Self.outgoing(), scopes: VariableScopes(), signIn: signIn.signIn)

        let queries = signIn.opened.map { FakeSignIn.query(of: $0.url) }
        #expect(queries.count == 2)
        #expect(queries.first?["state"] != queries.last?["state"])
        #expect(queries.first?["code_challenge"] != queries.last?["code_challenge"])
    }

    @Test("The code is exchanged at the Token URL with the verifier its challenge was made from")
    func exchangesTheCode() async throws {
        let signIn = FakeSignIn()
        let transport = ScriptedTransport(Self.issued)

        _ = try await tokens(transport)
            .getNewToken(for: Self.outgoing(), scopes: VariableScopes(), signIn: signIn.signIn)

        let challenge = try #require(signIn.opened.first.map { FakeSignIn.query(of: $0.url)["code_challenge"] })
        let tokenRequest = try #require(transport.requests.first)
        let form = FakeSignIn.form(of: tokenRequest)
        #expect(tokenRequest.url?.absoluteString == "https://auth.example.com/token")
        #expect(form["grant_type"] == "authorization_code")
        #expect(form["code"] == "c0de")
        #expect(form["redirect_uri"] == "moth://oauth/callback")
        #expect(try PKCE(verifier: #require(form["code_verifier"])).challenge == challenge)
        #expect(
            tokenRequest.value(forHTTPHeaderField: "Authorization")
                == "Basic \(Data("moth:s3cret".utf8).base64EncodedString())"
        )
    }

    @Test("An empty Client Secret exchanges the code with no credentials, naming the client in the form")
    func publicClient() async throws {
        let transport = ScriptedTransport(Self.issued)

        _ = try await tokens(transport)
            .getNewToken(for: Self.outgoing(clientSecret: nil), scopes: VariableScopes(), signIn: FakeSignIn().signIn)

        #expect(transport.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(FakeSignIn.form(of: transport.requests.first)["client_id"] == "moth")
    }

    @Test("Both tokens are kept in the Keychain, and neither is in the row")
    func storesBothTokens() async throws {
        let outgoing = Self.outgoing()

        let token = try await tokens(ScriptedTransport(Self.issued))
            .getNewToken(for: outgoing, scopes: VariableScopes(), signIn: FakeSignIn().signIn)

        let expected = OAuth2Token(
            value: "acc3ss",
            expiresAt: Self.now.addingTimeInterval(3600),
            issuedFor: "https://auth.example.com/token\nmoth\nread\nauthorization_code",
            refreshToken: "r3fresh"
        )
        let row = try #require(String(bytes: JSONEncoder().encode(outgoing.request.auth), encoding: .utf8))
        #expect(token == expected)
        #expect(await storedToken() == expected)
        #expect(!row.contains("acc3ss"))
        #expect(!row.contains("r3fresh"))
    }

    @Test("A callback with another state requests no token")
    func wrongStateRequestsNoToken() async {
        let signIn = FakeSignIn { _ in try FakeSignIn.callback("code=c0de&state=forged") }
        let transport = ScriptedTransport(Self.issued)

        await #expect(throws: OAuth2TokenError.stateMismatch) {
            try await tokens(transport).getNewToken(
                for: Self.outgoing(),
                scopes: VariableScopes(),
                signIn: signIn.signIn
            )
        }
        #expect(transport.requests.isEmpty)
        #expect(await storedToken() == nil)
    }

    @Test("A cancelled sign-in leaves the stored token as it was")
    func cancelledSignIn() async {
        let stored = OAuth2Token(value: "kept", expiresAt: nil, refreshToken: "kept-refresh")
        await secretStore.save(stored.storedValue, for: Self.accessToken.identifier)
        let signIn = FakeSignIn { _ in throw CancellationError() }
        let transport = ScriptedTransport(Self.issued)

        await #expect(throws: CancellationError.self) {
            try await tokens(transport).getNewToken(
                for: Self.outgoing(),
                scopes: VariableScopes(),
                signIn: signIn.signIn
            )
        }
        #expect(transport.requests.isEmpty)
        #expect(await storedToken() == stored)
    }

    @Test("A provider's error is reported with its description, and no token is requested")
    func providerError() async {
        let signIn = FakeSignIn { _ in
            try FakeSignIn.callback("error=access_denied&error_description=The%20user%20said%20no.")
        }
        let transport = ScriptedTransport(Self.issued)

        await #expect(throws: OAuth2TokenError.signInRefused(
            error: "access_denied",
            description: "The user said no."
        )) {
            try await tokens(transport).getNewToken(
                for: Self.outgoing(),
                scopes: VariableScopes(),
                signIn: signIn.signIn
            )
        }
        #expect(transport.requests.isEmpty)
    }

    @Test("A Callback URL that isn't a custom scheme opens no sign-in")
    func webCallbackOpensNoSignIn() async {
        let signIn = FakeSignIn()

        await #expect(throws: OAuth2TokenError.callbackNotCustomScheme) {
            try await tokens(ScriptedTransport(Self.issued)).getNewToken(
                for: Self.outgoing(callbackURL: "https://oauth.pstmn.io/v1/callback"),
                scopes: VariableScopes(),
                signIn: signIn.signIn
            )
        }
        #expect(signIn.opened.isEmpty)
    }

}
