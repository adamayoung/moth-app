//  Auth+SecretReferences.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated extension Auth {

    var secretReferences: Set<SecretReference> {
        switch self {
        case .inherit, .none:
            []
        case .basic(let basic):
            [basic.password]
        case .bearer(let bearer):
            [bearer.token]
        case .apiKey(let apiKey):
            [apiKey.value]
        case .digest(let digest):
            [digest.password]
        case .oauth2(let oauth2):
            Set(
                [oauth2.clientSecret, oauth2.password, oauth2.accessToken, oauth2.refreshToken].compactMap(\.self)
            )
        case .awsSigV4(let sigV4):
            Set([sigV4.accessKeyID, sigV4.secretAccessKey, sigV4.sessionToken].compactMap(\.self))
        }
    }

}
