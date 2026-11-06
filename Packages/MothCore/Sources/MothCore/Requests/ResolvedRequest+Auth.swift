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

    var authNotice: RequestBuildNotice? {
        switch auth {
        case .none, .basic, .bearer:
            nil
        case .inherit:
            .inheritNotReplaced
        case .apiKey:
            .unsupportedAuth(.apiKey)
        case .digest:
            .unsupportedAuth(.digest)
        case .oauth2:
            .unsupportedAuth(.oauth2)
        case .awsSigV4:
            .unsupportedAuth(.awsSigV4)
        }
    }

}
