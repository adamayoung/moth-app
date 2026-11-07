//  RequestSender+OAuth2.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension RequestSender {

    /// An auth with no `accessToken` reference, from a row older than the editor's, gets a token for this send alone.
    func withAccessToken(_ resolved: ResolvedRequest, tokens: OAuth2Tokens) async throws -> ResolvedRequest {
        guard case .oauth2(var oauth2) = resolved.auth, oauth2.grantType == .clientCredentials else {
            return resolved
        }
        let token: String
        do {
            token = try await tokens.validToken(for: oauth2, in: resolved)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AccessTokenFailure(failure: SendFailure(
                kind: .accessTokenFailed,
                description: error.localizedDescription
            ))
        }

        var authorised = resolved
        let reference = oauth2.accessToken ?? SecretReference()
        oauth2.accessToken = reference
        authorised.auth = .oauth2(oauth2)
        authorised.credentials[reference] = token
        return authorised
    }

}

struct AccessTokenFailure: Error {

    let failure: SendFailure

}
