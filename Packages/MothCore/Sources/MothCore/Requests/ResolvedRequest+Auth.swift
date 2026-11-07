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

    /// Lowercased. A row with one of these names doesn't reach the wire, so its variables don't count as unresolved.
    var headersReplacedByAuth: Set<String> {
        guard case .awsSigV4(let sigV4) = auth else {
            return ["authorization"]
        }

        var names: Set = ["authorization", "x-amz-date"]
        if sigV4.sessionToken.flatMap({ credentials[$0] })?.isEmpty == false {
            names.insert("x-amz-security-token")
        }
        if sigV4.service == AWSSigV4Signer.s3 {
            names.insert("x-amz-content-sha256")
        }
        return names
    }

    var authNotice: RequestBuildNotice? {
        switch auth {
        case .none, .basic, .bearer, .awsSigV4:
            nil
        case .inherit:
            .inheritNotReplaced
        case .apiKey:
            .unsupportedAuth(.apiKey)
        case .digest:
            .unsupportedAuth(.digest)
        case .oauth2:
            .unsupportedAuth(.oauth2)
        }
    }

}
