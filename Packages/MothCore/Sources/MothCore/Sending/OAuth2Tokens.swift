//  OAuth2Tokens.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

public typealias OAuth2SignIn = @MainActor (_ authorizationURL: URL, _ callbackScheme: String) async throws -> URL

/// Keeps each token under its auth's `accessToken` reference, so every request inheriting that auth shares it. Never
/// logs, and the token request carries no cookies and goes to no History.
public nonisolated struct OAuth2Tokens: Sendable {

    private let transport: any HTTPTransport
    let secretStore: any SecretStore
    let now: @Sendable () -> Date
    let randomBytes: @Sendable (Int) -> Data

    public init(
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        now: @escaping @Sendable () -> Date = { Date() },
        randomBytes: @escaping @Sendable (Int) -> Data = { count in
            Data((0 ..< count).map { _ in UInt8.random(in: .min ... .max) })
        }
    ) {
        self.transport = transport
        self.secretStore = secretStore
        self.now = now
        self.randomBytes = randomBytes
    }

    public func token(for reference: SecretReference) async throws -> OAuth2Token? {
        try await secretStore.value(for: reference.identifier).map(OAuth2Token.init(storedValue:))
    }

    public func clearToken(for reference: SecretReference) async throws {
        try await secretStore.removeValue(for: reference.identifier)
    }

    /// Resolves the way a send does, so the active environment and a Client Secret typed but not saved both apply.
    @concurrent
    public func getNewToken(
        for outgoing: OutgoingRequest,
        scopes: VariableScopes,
        signIn: OAuth2SignIn
    ) async throws -> OAuth2Token {
        let resolved = try await outgoing.withTokenReference.resolved(with: secretStore, scopes: scopes)
        guard case .oauth2(let oauth2) = resolved.auth else {
            throw OAuth2TokenError.unsupportedGrant
        }
        switch oauth2.grantType {
        case .clientCredentials:
            return try await fetchToken(for: oauth2, in: resolved, grant: .clientCredentials)
        case .authorizationCodeWithPKCE:
            return try await self.signIn(for: oauth2, in: resolved, with: signIn)
        case .authorizationCode, .implicit, .passwordCredentials:
            throw OAuth2TokenError.unsupportedGrant
        }
    }

    func validToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> String {
        guard oauth2.grantType == .clientCredentials else {
            return try await signedInToken(for: oauth2, in: resolved)
        }
        return try await clientCredentialsToken(for: oauth2, in: resolved)
    }

    /// A stored token issued for another Token URL, Client ID or Scope, or an imported one, is replaced.
    private func clientCredentialsToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> String {
        if let stored = try await token(for: oauth2.tokenReference),
           stored.issuedFor == Self.issuedFor(oauth2, in: resolved), !stored.needsRenewal(at: now()) {
            return stored.value
        }
        return try await fetchToken(for: oauth2, in: resolved, grant: .clientCredentials).value
    }

    static func tokenRequest(
        for oauth2: OAuth2Auth,
        in resolved: ResolvedRequest,
        grant: OAuth2TokenRequest.Grant = .clientCredentials
    ) -> OAuth2TokenRequest {
        OAuth2TokenRequest(
            tokenURL: oauth2.accessTokenURL,
            clientID: oauth2.clientID,
            clientSecret: oauth2.clientSecret.flatMap { resolved.credentials[$0] } ?? "",
            scope: oauth2.scope,
            grant: grant
        )
    }

    /// A refresh whose answer carries no refresh token keeps the one it used, as RFC 6749 section 6 allows.
    func fetchToken(
        for oauth2: OAuth2Auth,
        in resolved: ResolvedRequest,
        grant: OAuth2TokenRequest.Grant
    ) async throws -> OAuth2Token {
        let tokenRequest = Self.tokenRequest(for: oauth2, in: resolved, grant: grant)
        let settings = resolved.settings
        let response = try await transport.send(
            tokenRequest.urlRequest(timeout: settings.timeout),
            cookies: nil,
            policy: SendPolicy(followsRedirects: settings.followsRedirects, verifiesTLS: settings.verifiesTLS)
        )
        var token = try OAuth2TokenRequest.token(from: response, receivedAt: now())
        token.issuedFor = Self.issuedFor(oauth2, in: resolved)
        if case .refreshToken(let used) = grant, token.refreshToken == nil {
            token.refreshToken = used
        }
        try await secretStore.save(token.storedValue, for: oauth2.tokenReference.identifier)
        return token
    }

}

extension OutgoingRequest {

    func resolved(
        with secretStore: any SecretStore,
        scopes: VariableScopes,
        dynamicVariables: DynamicVariables = .live
    ) async throws -> ResolvedRequest {
        let credentials = TypedCredentialStore(typed: typedCredentials, stored: secretStore)
        return try await VariableResolver(secretStore: credentials, dynamicVariables: dynamicVariables).resolve(
            request,
            collection: scopes.collection,
            environment: scopes.environment,
            globals: scopes.globals
        )
    }

}
