//  OAuth2Tokens+AuthorizationCode.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension OAuth2Tokens {

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

    /// A send can't open a sign-in, so with no usable token it stops. An imported token records nothing it was
    /// issued for and can't be refreshed, so it is sent as it is. A refresh token goes only to the Token URL it came
    /// from, and only a refusal removes it; whatever a refresh does, a token that hasn't expired is still sent.
    func signedInToken(for oauth2: OAuth2Auth, in resolved: ResolvedRequest) async throws -> String {
        let reference = oauth2.tokenReference
        guard let stored = try await token(for: reference) else {
            throw OAuth2TokenError.signInNeeded
        }
        guard let issuedFor = stored.issuedFor else {
            return stored.value
        }
        guard issuedFor == Self.issuedFor(oauth2, in: resolved) else {
            throw OAuth2TokenError.issuedForOtherFields
        }
        guard stored.needsRenewal(at: now()) else {
            return stored.value
        }
        guard let refreshToken = stored.refreshToken else {
            return try unexpiredValue(of: stored)
        }

        do {
            return try await fetchToken(for: oauth2, in: resolved, grant: .refreshToken(refreshToken)).value
        } catch let error as OAuth2TokenError where error.refusesTheGrant {
            return try await afterRefusal(of: refreshToken, stored: stored, under: reference)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard case .expired = stored.state(at: now()) else {
                return stored.value
            }
            throw error
        }
    }

    /// Another send may have refreshed, or the person signed in again, while this refresh was refused: their token
    /// stays, and only the refused refresh token is dropped.
    private func afterRefusal(
        of refreshToken: String,
        stored: OAuth2Token,
        under reference: SecretReference
    ) async throws -> String {
        let current = try await token(for: reference)
        if var refused = current, refused.refreshToken == refreshToken {
            refused.refreshToken = nil
            try await secretStore.save(refused.storedValue, for: reference.identifier)
            return try unexpiredValue(of: refused)
        }
        if let current, current.issuedFor == stored.issuedFor, !current.needsRenewal(at: now()) {
            return current.value
        }
        throw OAuth2TokenError.tokenExpired
    }

    private func unexpiredValue(of token: OAuth2Token) throws -> String {
        guard case .expired = token.state(at: now()) else {
            return token.value
        }
        throw OAuth2TokenError.tokenExpired
    }

    /// Names the grant, so a Client Credentials token is never sent as a person's, nor theirs as the client's. Client
    /// Credentials keeps the fingerprint it has always stored.
    static func issuedFor(_ oauth2: OAuth2Auth, in resolved: ResolvedRequest) -> String {
        let fingerprint = tokenRequest(for: oauth2, in: resolved).fingerprint
        return oauth2.grantType == .clientCredentials ? fingerprint : fingerprint + "\nauthorization_code"
    }

}

nonisolated extension OAuth2TokenError {

    /// RFC 6749 section 5.2 answers a refused grant with 400, or 401 for the client. A server error or a rate limit
    /// says nothing about the refresh token.
    var refusesTheGrant: Bool {
        guard case .refused(let status, _, _) = self else {
            return false
        }
        return status == 400 || status == 401
    }

}
