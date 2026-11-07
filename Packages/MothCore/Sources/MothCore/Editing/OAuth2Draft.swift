//  OAuth2Draft.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Edits the fields a supported grant uses and carries the rest through unchanged, so a Save keeps what an import
/// brought. The Client Secret is optional, as AWS's Session Token is, because RFC 6749 lets a client have none.
public nonisolated struct OAuth2Draft: Sendable {

    public static let supportedGrantTypes: [OAuth2GrantType] = [.clientCredentials]

    public var grantType = OAuth2GrantType.clientCredentials
    public var tokenURL = ""
    public var clientID = ""
    public var scope = ""
    private var stored: OAuth2Auth?
    private var clientSecret = DraftCredential()
    private var storedAccessToken: SecretReference?
    private var newAccessToken = SecretReference()

    init() {}

    init(_ auth: OAuth2Auth) {
        self.grantType = auth.grantType
        self.tokenURL = auth.accessTokenURL
        self.clientID = auth.clientID
        self.scope = auth.scope
        self.stored = auth
        clientSecret.stored = auth.clientSecret
        self.storedAccessToken = auth.accessToken
    }

    public var grantTypes: [OAuth2GrantType] {
        guard let storedGrant = stored?.grantType, !Self.supportedGrantTypes.contains(storedGrant) else {
            return Self.supportedGrantTypes
        }
        return Self.supportedGrantTypes + [storedGrant]
    }

    public var isSupported: Bool {
        Self.supportedGrantTypes.contains(grantType)
    }

    public var clientSecretReference: SecretReference {
        clientSecret.reference
    }

    /// Minted for a row that holds none, so a token has somewhere to go before the next Save writes the row.
    public var accessTokenReference: SecretReference {
        storedAccessToken ?? newAccessToken
    }

    var auth: OAuth2Auth {
        var auth = stored ?? OAuth2Auth(
            grantType: grantType,
            authorizationURL: "",
            accessTokenURL: "",
            callbackURL: "",
            clientID: "",
            scope: ""
        )
        auth.grantType = grantType
        auth.accessTokenURL = tokenURL
        auth.clientID = clientID
        auth.scope = scope
        auth.clientSecret = clientSecret.savedIfSet
        auth.accessToken = accessTokenReference
        return auth
    }

    var writes: [CredentialWrite] {
        clientSecret.write.map { [$0] } ?? []
    }

    var typedText: [String?] {
        [clientSecret.typed]
    }

    func typedCredential(for reference: SecretReference) -> String? {
        reference == clientSecret.reference ? clientSecret.typed : nil
    }

    mutating func setCredential(_ text: String, for reference: SecretReference) {
        if reference == clientSecret.reference {
            clientSecret.typed = text
        }
    }

    mutating func discardCredentials(where isStored: (SecretReference, String) -> Bool) {
        if let typed = clientSecret.typed, isStored(clientSecret.reference, typed) {
            clientSecret.typed = nil
        }
    }

    mutating func follow(_ saved: OAuth2Draft) {
        grantType = saved.grantType
        tokenURL = saved.tokenURL
        clientID = saved.clientID
        scope = saved.scope
        clientSecret.typed = nil
        if saved.storedAccessToken == nil {
            newAccessToken = saved.newAccessToken
        }
    }

    mutating func rebaseCredentials(onto saved: OAuth2Draft) {
        stored = saved.stored
        clientSecret.rebase(onto: saved.clientSecret)
        storedAccessToken = saved.storedAccessToken
        if newAccessToken == storedAccessToken {
            newAccessToken = SecretReference()
        }
    }

}
