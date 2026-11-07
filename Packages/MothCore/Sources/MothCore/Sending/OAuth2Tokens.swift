//  OAuth2Tokens.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// Keeps each token under its auth's `accessToken` reference, so every request inheriting that auth shares it. Never
/// logs, and the token request carries no cookies and goes to no History.
public nonisolated struct OAuth2Tokens: Sendable {

    private let transport: any HTTPTransport
    private let secretStore: any SecretStore
    private let now: @Sendable () -> Date

    public init(
        transport: any HTTPTransport,
        secretStore: any SecretStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.secretStore = secretStore
        self.now = now
    }

    public func token(for reference: SecretReference) async throws -> OAuth2Token? {
        try await secretStore.value(for: reference.identifier).map(OAuth2Token.init(storedValue:))
    }

    public func clearToken(for reference: SecretReference) async throws {
        try await secretStore.removeValue(for: reference.identifier)
    }

    /// Resolves the way a send does, so the active environment and a Client Secret typed but not saved both apply.
    @concurrent
    public func getNewToken(for outgoing: OutgoingRequest, scopes: VariableScopes) async throws -> OAuth2Token {
        let resolved = try await outgoing.withTokenReference.resolved(with: secretStore, scopes: scopes)
        guard case .oauth2(let oauth2) = resolved.auth, oauth2.grantType == .clientCredentials else {
            throw OAuth2TokenError.unsupportedGrant
        }
        return try await fetchToken(for: oauth2, in: resolved)
    }

    /// A stored token issued for another Token URL, Client ID or Scope, or an imported one, is replaced.
    func validToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> String {
        let fingerprint = Self.tokenRequest(for: oauth2, in: resolved).fingerprint
        if let stored = try await token(for: oauth2.tokenReference),
           stored.issuedFor == fingerprint, !stored.needsRenewal(at: now()) {
            return stored.value
        }
        return try await fetchToken(for: oauth2, in: resolved).value
    }

    private static func tokenRequest(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) -> OAuth2TokenRequest {
        OAuth2TokenRequest(
            tokenURL: oauth2.accessTokenURL,
            clientID: oauth2.clientID,
            clientSecret: oauth2.clientSecret.flatMap { resolved.credentials[$0] } ?? "",
            scope: oauth2.scope
        )
    }

    private func fetchToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> OAuth2Token {
        let tokenRequest = Self.tokenRequest(for: oauth2, in: resolved)
        let settings = resolved.settings
        let response = try await transport.send(
            tokenRequest.urlRequest(timeout: settings.timeout),
            cookies: nil,
            policy: SendPolicy(followsRedirects: settings.followsRedirects, verifiesTLS: settings.verifiesTLS)
        )
        var token = try OAuth2TokenRequest.token(from: response, receivedAt: now())
        token.issuedFor = tokenRequest.fingerprint
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
