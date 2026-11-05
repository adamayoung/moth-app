//  ResolvedRequest+Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

nonisolated extension ResolvedRequest {

    /// `nil` for a credential with no value too, which `unresolvedCredentials` has already reported.
    var authProvider: any AuthProvider? {
        switch auth {
        case .basic(let basic):
            credentials[basic.password].map { BasicAuthProvider(username: basic.username, password: $0) }
        case .bearer(let bearer):
            credentials[bearer.token].map { BearerAuthProvider(token: $0) }
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4:
            nil
        }
    }

    var unsupportedAuthKind: UnsupportedAuthKind? {
        switch auth {
        case .inherit, .none, .basic, .bearer:
            nil
        case .apiKey:
            .apiKey
        case .digest:
            .digest
        case .oauth2:
            .oauth2
        case .awsSigV4:
            .awsSigV4
        }
    }

}
