//  OAuth2Tokens+AuthorizationCode.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension OAuth2Tokens {

    /// A fresh state and PKCE verifier for each sign-in, and no token request unless the callback carries that state.
    func signIn(
        for oauth2: OAuth2Auth,
        in resolved: ResolvedRequest,
        with signIn: OAuth2SignIn
    ) async throws -> OAuth2Token {
        let pkce = PKCE(randomBytes: randomBytes(32))
        let request = OAuth2SignInRequest(
            authorizationURL: oauth2.authorizationURL,
            clientID: oauth2.clientID,
            callbackURL: oauth2.callbackURL,
            scope: oauth2.scope,
            state: randomBytes(32).base64URLEncoded,
            pkce: pkce
        )
        let callbackScheme = try request.callbackScheme()
        let callback = try await signIn(request.url(), callbackScheme)
        let code = try request.code(from: callback)
        return try await fetchToken(
            for: oauth2,
            in: resolved,
            grant: .authorizationCode(code: code, redirectURI: oauth2.callbackURL, verifier: pkce.verifier)
        )
    }

    /// A send can't open a sign-in, so with no usable token it stops. A refresh token goes only to the Token URL
    /// it was issued by, and only a refusal removes it: an unreachable Token URL may answer next time.
    func signedInToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> String {
        guard let stored = try await token(for: oauth2.tokenReference) else {
            throw OAuth2TokenError.signInNeeded
        }
        guard stored.issuedFor == Self.tokenRequest(for: oauth2, in: resolved).fingerprint else {
            throw OAuth2TokenError.issuedForOtherFields
        }
        guard stored.needsRenewal(at: now()) else {
            return stored.value
        }
        guard let refreshToken = stored.refreshToken else {
            guard case .expired = stored.state(at: now()) else {
                return stored.value
            }
            throw OAuth2TokenError.tokenExpired
        }

        do {
            return try await fetchToken(for: oauth2, in: resolved, grant: .refreshToken(refreshToken)).value
        } catch OAuth2TokenError.refused {
            var expired = stored
            expired.refreshToken = nil
            try await secretStore.save(expired.storedValue, for: oauth2.tokenReference.identifier)
            throw OAuth2TokenError.tokenExpired
        }
    }

}
