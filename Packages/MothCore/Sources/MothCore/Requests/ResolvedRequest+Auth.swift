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
        case .apiKey(let apiKey) where !apiKey.name.isEmpty:
            credentials[apiKey.value].map {
                APIKeyAuthProvider(name: apiKey.name, value: $0, location: apiKey.location)
            }
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
        case .apiKey(let apiKey):
            apiKey.name.isEmpty ? .apiKeyWithoutName : nil
        case .digest:
            .unsupportedAuth(.digest)
        case .oauth2:
            .unsupportedAuth(.oauth2)
        case .awsSigV4:
            .unsupportedAuth(.awsSigV4)
        }
    }

    var rowsReplacedByAuth: Set<RequestPart> {
        guard case .apiKey(let apiKey) = auth else {
            return rows(of: headers, named: "Authorization")
        }

        switch apiKey.location {
        case .header:
            return rows(of: headers, named: apiKey.name)
        case .query:
            return Set(queryParameters.filter { $0.key == apiKey.name }.map { .row($0.id) })
        }
    }

    private func rows(of headers: [KeyValue], named name: String) -> Set<RequestPart> {
        Set(headers.filter { $0.key.caseInsensitiveCompare(name) == .orderedSame }.map { .row($0.id) })
    }

}
