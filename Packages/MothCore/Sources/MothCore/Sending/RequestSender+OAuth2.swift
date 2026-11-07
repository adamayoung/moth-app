//  RequestSender+OAuth2.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension RequestSender {

    /// Builds once first, so a request that can't be sent never sends its client secret to the token endpoint.
    func authorised(
        _ resolved: ResolvedRequest,
        tokens: OAuth2Tokens,
        at sentAt: Date
    ) async throws -> ResolvedRequest {
        guard resolved.getsAccessTokenAtSend, case .oauth2(let oauth2) = resolved.auth else {
            return resolved
        }
        _ = try await RequestBuilder(now: { sentAt }).build(resolved)

        let token: String
        do {
            token = try await tokens.validToken(for: oauth2, in: resolved)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AccessTokenFailure(
                failure: SendFailure(kind: .accessTokenFailed, description: error.localizedDescription),
                notes: ResponseNote.notes(
                    unresolved: resolved.unresolved,
                    notices: [],
                    unresolvedCredentials: resolved.unresolvedCredentials
                )
            )
        }

        var authorised = resolved
        authorised.credentials[oauth2.tokenReference] = token
        return authorised
    }

}

nonisolated extension OutgoingRequest {

    /// Done before resolution, because the reference derives from the fields as written, not as an environment
    /// expands them.
    var withTokenReference: OutgoingRequest {
        guard case .oauth2(var oauth2) = request.auth, oauth2.accessToken == nil else {
            return self
        }
        var outgoing = self
        oauth2.accessToken = oauth2.tokenReference
        outgoing.request.auth = .oauth2(oauth2)
        return outgoing
    }

}

struct AccessTokenFailure: Error {

    let failure: SendFailure
    let notes: [ResponseNote]

}
