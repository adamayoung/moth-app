//  AuthDraft.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated enum AuthKind: Sendable, Hashable {

    case inherit
    case none
    case basic
    case bearer
    case apiKey
    case digest
    case oauth2
    case awsSigV4

    public static let editable: [AuthKind] = [.inherit, .none, .basic, .bearer, .apiKey, .digest, .oauth2, .awsSigV4]

    init(_ auth: Auth) {
        switch auth {
        case .inherit: self = .inherit
        case .none: self = .none
        case .basic: self = .basic
        case .bearer: self = .bearer
        case .apiKey: self = .apiKey
        case .digest: self = .digest
        case .oauth2: self = .oauth2
        case .awsSigV4: self = .awsSigV4
        }
    }

}

public nonisolated struct CredentialWrite: Sendable, Hashable {

    public let reference: SecretReference
    public let value: String

    public init(reference: SecretReference, value: String) {
        self.reference = reference
        self.value = value
    }

}

/// Typed credentials stay here and never reach `requestAuth`, which is the form that goes to a row. A changed
/// credential
/// takes a new reference, and the row moves to it: writing over one a row holds would change the secret for a Save that
/// then fails. New references are minted up front, so a Save tried again writes the same item.
public nonisolated struct AuthDraft: Sendable {

    public var kind: AuthKind
    public var username = ""
    public var apiKeyName = ""
    public var apiKeyLocation = APIKeyLocation.header
    public var awsSigV4 = AWSSigV4Draft()
    public var oauth2 = OAuth2Draft()
    private var storedPassword: SecretReference?
    private var storedToken: SecretReference?
    private var storedAPIKeyValue: SecretReference?
    private var newPassword = SecretReference()
    private var newToken = SecretReference()
    private var newAPIKeyValue = SecretReference()
    private var typedPassword: String?
    private var typedToken: String?
    private var typedAPIKeyValue: String?

    public init(_ auth: Auth) {
        self.kind = AuthKind(auth)
        switch auth {
        case .inherit, .none:
            break
        case .basic(let basic):
            self.username = basic.username
            self.storedPassword = basic.password
        case .digest(let digest):
            self.username = digest.username
            self.storedPassword = digest.password
        case .bearer(let bearer):
            self.storedToken = bearer.token
        case .awsSigV4(let sigV4):
            self.awsSigV4 = AWSSigV4Draft(sigV4)
        case .apiKey(let apiKey):
            self.apiKeyName = apiKey.name
            self.apiKeyLocation = apiKey.location
            self.storedAPIKeyValue = apiKey.value
        case .oauth2(let oauth2):
            self.oauth2 = OAuth2Draft(oauth2)
        }
    }

    public var requestAuth: Auth {
        switch kind {
        case .inherit: .inherit
        case .none: .none
        case .basic: .basic(BasicAuth(username: username, password: savedPassword))
        case .digest: .digest(DigestAuth(username: username, password: savedPassword))
        case .bearer: .bearer(BearerAuth(token: typedToken == nil ? tokenReference : newToken))
        case .awsSigV4: .awsSigV4(awsSigV4.auth)
        case .apiKey: .apiKey(APIKeyAuth(
                name: apiKeyName,
                value: typedAPIKeyValue == nil ? apiKeyValueReference : newAPIKeyValue,
                location: apiKeyLocation
            ))
        case .oauth2: .oauth2(oauth2.auth)
        }
    }

    public var kinds: [AuthKind] {
        AuthKind.editable
    }

    public var passwordReference: SecretReference {
        storedPassword ?? newPassword
    }

    private var savedPassword: SecretReference {
        typedPassword == nil ? passwordReference : newPassword
    }

    public var tokenReference: SecretReference {
        storedToken ?? newToken
    }

    public var apiKeyValueReference: SecretReference {
        storedAPIKeyValue ?? newAPIKeyValue
    }

    public var credentialReferences: [SecretReference] {
        switch kind {
        case .basic, .digest: [passwordReference]
        case .bearer: [tokenReference]
        case .apiKey: [apiKeyValueReference]
        case .awsSigV4: awsSigV4.references
        case .oauth2: [oauth2.clientSecretReference]
        case .inherit, .none: []
        }
    }

    public func typedCredential(for reference: SecretReference) -> String? {
        if reference == passwordReference {
            typedPassword
        } else if reference == tokenReference {
            typedToken
        } else if reference == apiKeyValueReference {
            typedAPIKeyValue
        } else {
            awsSigV4.typedCredential(for: reference) ?? oauth2.typedCredential(for: reference)
        }
    }

    public mutating func setCredential(_ text: String, for reference: SecretReference) {
        if reference == passwordReference {
            typedPassword = text
        } else if reference == tokenReference {
            typedToken = text
        } else if reference == apiKeyValueReference {
            typedAPIKeyValue = text
        } else {
            awsSigV4.setCredential(text, for: reference)
            oauth2.setCredential(text, for: reference)
        }
    }

    /// Drops text the person has typed back to what is stored, which leaves nothing to save.
    public mutating func discardCredentials(where isStored: (SecretReference, String) -> Bool) {
        if let typedPassword, isStored(passwordReference, typedPassword) {
            self.typedPassword = nil
        }
        if let typedToken, isStored(tokenReference, typedToken) {
            self.typedToken = nil
        }
        if let typedAPIKeyValue, isStored(apiKeyValueReference, typedAPIKeyValue) {
            self.typedAPIKeyValue = nil
        }
        awsSigV4.discardCredentials(where: isStored)
        oauth2.discardCredentials(where: isStored)
    }

    /// A password is always saved, because Basic and Digest can send a username alone. An empty token or API key value
    /// is not, because a credential with no value is reported rather than sent.
    public func credentialWrites() -> [CredentialWrite] {
        switch kind {
        case .basic, .digest:
            if let typedPassword {
                [CredentialWrite(reference: newPassword, value: typedPassword)]
            } else if storedPassword == nil {
                [CredentialWrite(reference: newPassword, value: "")]
            } else {
                []
            }
        case .bearer:
            if let typedToken, !typedToken.isEmpty {
                [CredentialWrite(reference: newToken, value: typedToken)]
            } else {
                []
            }
        case .apiKey:
            if let typedAPIKeyValue, !typedAPIKeyValue.isEmpty {
                [CredentialWrite(reference: newAPIKeyValue, value: typedAPIKeyValue)]
            } else {
                []
            }
        case .awsSigV4:
            awsSigV4.writes
        case .oauth2:
            oauth2.writes
        case .inherit, .none:
            []
        }
    }

    /// Compares the text too, because two values typed before a Save share one new reference. Typing for a kind that
    /// isn't chosen is no change, because Save won't write it.
    public func hasSameContent(as other: AuthDraft) -> Bool {
        requestAuth == other.requestAuth && chosenCredentials == other.chosenCredentials
    }

    private var chosenCredentials: [String?] {
        switch kind {
        case .basic, .digest: [typedPassword]
        case .bearer: [typedToken]
        case .apiKey: [typedAPIKeyValue]
        case .awsSigV4: awsSigV4.typedText
        case .oauth2: oauth2.typedText
        case .inherit, .none: []
        }
    }

    /// Takes the chosen kind and its fields from what is saved, and keeps what was typed for the others.
    public mutating func follow(_ saved: AuthDraft) {
        kind = saved.kind
        switch saved.kind {
        case .basic, .digest:
            username = saved.username
            typedPassword = nil
        case .bearer:
            typedToken = nil
        case .apiKey:
            apiKeyName = saved.apiKeyName
            apiKeyLocation = saved.apiKeyLocation
            typedAPIKeyValue = nil
        case .awsSigV4:
            awsSigV4.follow(saved.awsSigV4)
        case .oauth2:
            oauth2.follow(saved.oauth2)
        case .inherit, .none:
            break
        }
        rebaseCredentials(onto: saved)
    }

    /// The row has moved, and holding on to its old references would release the new ones and lose their values.
    public mutating func rebaseCredentials(onto saved: AuthDraft) {
        storedPassword = saved.storedPassword
        storedToken = saved.storedToken
        storedAPIKeyValue = saved.storedAPIKeyValue
        awsSigV4.rebaseCredentials(onto: saved.awsSigV4)
        oauth2.rebaseCredentials(onto: saved.oauth2)
        if newPassword == storedPassword {
            newPassword = SecretReference()
        }
        if newToken == storedToken {
            newToken = SecretReference()
        }
        if newAPIKeyValue == storedAPIKeyValue {
            newAPIKeyValue = SecretReference()
        }
    }

}
