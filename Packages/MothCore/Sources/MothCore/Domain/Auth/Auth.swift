//  Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Each kind holds its credentials as a ``SecretReference``, so no credential can reach a model.
/// A `nil` reference means the kind has no such credential; one with no stored value has not synced yet.
public nonisolated enum Auth: Sendable, Hashable {

    case inherit
    case none
    case basic(BasicAuth)
    case bearer(BearerAuth)
    case apiKey(APIKeyAuth)
    case digest(DigestAuth)
    case oauth2(OAuth2Auth)
    case awsSigV4(AWSSigV4Auth)

}
