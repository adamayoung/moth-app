//  OAuth2Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct OAuth2Auth: Sendable, Hashable, Codable {

    public var grantType: OAuth2GrantType
    public var authorizationURL: String
    public var accessTokenURL: String
    public var callbackURL: String
    public var clientID: String
    public var clientSecret: SecretReference?
    public var scope: String
    public var username: String
    public var password: SecretReference?
    public var accessToken: SecretReference?
    public var refreshToken: SecretReference?

    public init(
        grantType: OAuth2GrantType,
        authorizationURL: String,
        accessTokenURL: String,
        callbackURL: String,
        clientID: String,
        clientSecret: SecretReference? = nil,
        scope: String,
        username: String = "",
        password: SecretReference? = nil,
        accessToken: SecretReference? = nil,
        refreshToken: SecretReference? = nil
    ) {
        self.grantType = grantType
        self.authorizationURL = authorizationURL
        self.accessTokenURL = accessTokenURL
        self.callbackURL = callbackURL
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scope = scope
        self.username = username
        self.password = password
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }

}

public nonisolated enum OAuth2GrantType: Sendable, Hashable, Codable {

    case authorizationCode
    case authorizationCodeWithPKCE
    case implicit
    case passwordCredentials
    case clientCredentials

    /// The grants Moth runs. Postman's Authorization Code without PKCE isn't one, because Moth always sends PKCE.
    public static let supported: [OAuth2GrantType] = [.clientCredentials, .authorizationCodeWithPKCE]

    public var isSupported: Bool {
        Self.supported.contains(self)
    }

}
