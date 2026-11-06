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

    public static let editable: [AuthKind] = [.inherit, .none, .basic, .bearer]

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
    private var storedPassword: SecretReference?
    private var storedToken: SecretReference?
    private var newPassword = SecretReference()
    private var newToken = SecretReference()
    private var typedPassword: String?
    private var typedToken: String?
    private var unsupportedAuth: Auth?

    public init(_ auth: Auth) {
        self.kind = AuthKind(auth)
        switch auth {
        case .inherit, .none:
            break
        case .basic(let basic):
            self.username = basic.username
            self.storedPassword = basic.password
        case .bearer(let bearer):
            self.storedToken = bearer.token
        case .apiKey, .digest, .oauth2, .awsSigV4:
            self.unsupportedAuth = auth
        }
    }

    public var requestAuth: Auth {
        switch kind {
        case .inherit: .inherit
        case .none: .none
        case .basic: .basic(BasicAuth(
                username: username,
                password: typedPassword == nil ? passwordReference : newPassword
            ))
        case .bearer: .bearer(BearerAuth(token: typedToken == nil ? tokenReference : newToken))
        case .apiKey, .digest, .oauth2, .awsSigV4: unsupportedAuth ?? .none
        }
    }

    /// An auth the editor can't change keeps its own entry, so choosing another kind can be undone before Save.
    public var kinds: [AuthKind] {
        AuthKind.editable + (unsupportedAuth.map { [AuthKind($0)] } ?? [])
    }

    public var passwordReference: SecretReference {
        storedPassword ?? newPassword
    }

    public var tokenReference: SecretReference {
        storedToken ?? newToken
    }

    public var credentialReference: SecretReference? {
        switch kind {
        case .basic: passwordReference
        case .bearer: tokenReference
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4: nil
        }
    }

    public func typedCredential(for reference: SecretReference) -> String? {
        if reference == passwordReference {
            typedPassword
        } else if reference == tokenReference {
            typedToken
        } else {
            nil
        }
    }

    public mutating func setCredential(_ text: String, for reference: SecretReference) {
        if reference == passwordReference {
            typedPassword = text
        } else if reference == tokenReference {
            typedToken = text
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
    }

    /// A password is always saved, because Basic can send a username alone. An empty token is not, because a header
    /// can't send one, and a credential with no value is reported rather than sent.
    public func credentialWrites() -> [CredentialWrite] {
        switch kind {
        case .basic:
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
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4:
            []
        }
    }

    /// Compares the text too, because two values typed before a Save share one new reference. Typing for a kind that
    /// isn't chosen is no change, because Save won't write it.
    public func hasSameContent(as other: AuthDraft) -> Bool {
        requestAuth == other.requestAuth && chosenCredential == other.chosenCredential
    }

    private var chosenCredential: String? {
        switch kind {
        case .basic: typedPassword
        case .bearer: typedToken
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4: nil
        }
    }

    /// Takes the chosen kind and its fields from what is saved, and keeps what was typed for the others.
    public mutating func follow(_ saved: AuthDraft) {
        kind = saved.kind
        unsupportedAuth = saved.unsupportedAuth
        if saved.kind == .basic {
            username = saved.username
        }
        rebaseCredentials(onto: saved)
    }

    /// The row has moved, and holding on to its old references would release the new ones and lose their values.
    public mutating func rebaseCredentials(onto saved: AuthDraft) {
        storedPassword = saved.storedPassword
        storedToken = saved.storedToken
        if newPassword == storedPassword {
            newPassword = SecretReference()
        }
        if newToken == storedToken {
            newToken = SecretReference()
        }
    }

}
