//  ResolvedRequest+Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension ResolvedRequest {

    /// `nil` for a credential with no value too, which `unresolvedCredentials` has already reported. AWS Signature's
    /// required ones stop the build instead, because an unsigned call to AWS would come back as a bare 403.
    func authProvider(signingAt date: Date) -> (any AuthProvider)? {
        switch auth {
        case .basic(let basic):
            credentials[basic.password].map { BasicAuthProvider(username: basic.username, password: $0) }
        case .bearer(let bearer):
            credentials[bearer.token].map { BearerAuthProvider(token: $0) }
        case .apiKey(let apiKey) where !apiKey.name.isEmpty:
            credentials[apiKey.value].map {
                APIKeyAuthProvider(name: apiKey.name, value: $0, location: apiKey.location)
            }
        case .awsSigV4(let sigV4):
            awsSigV4Provider(sigV4, signingAt: date)
        case .inherit, .none, .apiKey, .digest, .oauth2:
            nil
        }
    }

    var authNotice: RequestBuildNotice? {
        switch auth {
        case .none, .basic, .bearer, .awsSigV4:
            nil
        case .inherit:
            .inheritNotReplaced
        case .apiKey(let apiKey):
            apiKey.name.isEmpty ? .apiKeyWithoutName : nil
        case .digest:
            .unsupportedAuth(.digest)
        case .oauth2:
            .unsupportedAuth(.oauth2)
        }
    }

    var rowsReplacedByAuth: Set<RequestPart> {
        guard case .apiKey(let apiKey) = auth else {
            return headersSetByAuth.reduce(into: []) { $0.formUnion(rows(of: headers, named: $1)) }
        }

        switch apiKey.location {
        case .header:
            return rows(of: headers, named: apiKey.name)
        case .query:
            return Set(queryParameters.filter { $0.key == apiKey.name }.map { .row($0.id) })
        }
    }

    private var headersSetByAuth: [String] {
        guard case .awsSigV4(let sigV4) = auth else {
            return ["Authorization"]
        }

        return awsSigV4Provider(sigV4, signingAt: .distantPast).headersSet
    }

    private func awsSigV4Provider(_ sigV4: AWSSigV4Auth, signingAt date: Date) -> AWSSigV4AuthProvider {
        AWSSigV4AuthProvider(
            accessKey: credentials[sigV4.accessKeyID] ?? "",
            secretKey: credentials[sigV4.secretAccessKey] ?? "",
            sessionToken: sigV4.sessionToken.flatMap { credentials[$0] },
            region: sigV4.region,
            service: sigV4.service,
            date: date
        )
    }

    private func rows(of headers: [KeyValue], named name: String) -> Set<RequestPart> {
        Set(headers.filter { $0.key.caseInsensitiveCompare(name) == .orderedSame }.map { .row($0.id) })
    }

}
