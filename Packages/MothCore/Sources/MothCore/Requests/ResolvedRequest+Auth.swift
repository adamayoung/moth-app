//  ResolvedRequest+Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated extension ResolvedRequest {

    /// `nil` for a credential with no value too, which `unresolvedCredentials` has already reported. AWS Signature
    /// stops the build instead, because an unsigned call to AWS would come back as a bare 403.
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
            AWSSigV4AuthProvider(
                accessKey: credentials[sigV4.accessKeyID] ?? "",
                secretKey: credentials[sigV4.secretAccessKey] ?? "",
                sessionToken: sigV4.sessionToken.flatMap { credentials[$0] },
                region: sigV4.region,
                service: sigV4.service,
                date: date
            )
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

        var names = ["Authorization", "X-Amz-Date"]
        if sigV4.sessionToken.flatMap({ credentials[$0] })?.isEmpty == false {
            names.append("X-Amz-Security-Token")
        }
        if sigV4.service == AWSSigV4Signer.s3 {
            names.append("X-Amz-Content-Sha256")
        }
        return names
    }

    private func rows(of headers: [KeyValue], named name: String) -> Set<RequestPart> {
        Set(headers.filter { $0.key.caseInsensitiveCompare(name) == .orderedSame }.map { .row($0.id) })
    }

}
