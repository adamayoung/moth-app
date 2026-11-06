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

/// What a Save asks of the secret store. A `nil` value removes what is stored.
public nonisolated struct CredentialWrite: Sendable, Hashable {

    public let reference: SecretReference
    public let value: String?

    public init(reference: SecretReference, value: String?) {
        self.reference = reference
        self.value = value
    }

}

/// Typed credentials stay here and never reach `requestAuth`, which is the form that goes to a row. A draft mints its
/// references up front, so a Save that fails and is tried again writes the same items rather than leaving strays.
public nonisolated struct AuthDraft: Sendable {

    public var kind: AuthKind
    public var username = ""
    public private(set) var passwordReference = SecretReference()
    public private(set) var tokenReference = SecretReference()
    private var unsupportedAuth: Auth?
    private var typedCredentials: [SecretReference: String] = [:]

    public init(_ auth: Auth) {
        self.kind = AuthKind(auth)
        switch auth {
        case .inherit, .none:
            break
        case .basic(let basic):
            self.username = basic.username
            self.passwordReference = basic.password
        case .bearer(let bearer):
            self.tokenReference = bearer.token
        case .apiKey, .digest, .oauth2, .awsSigV4:
            self.unsupportedAuth = auth
        }
    }

    public var requestAuth: Auth {
        switch kind {
        case .inherit: .inherit
        case .none: .none
        case .basic: .basic(BasicAuth(username: username, password: passwordReference))
        case .bearer: .bearer(BearerAuth(token: tokenReference))
        case .apiKey, .digest, .oauth2, .awsSigV4: unsupportedAuth ?? .none
        }
    }

    /// An auth the editor can't change keeps its own entry, so choosing another kind can be undone before Save.
    public var kinds: [AuthKind] {
        AuthKind.editable + (unsupportedAuth.map { [AuthKind($0)] } ?? [])
    }

    /// The reference the chosen kind shows a field for.
    public var credentialReference: SecretReference? {
        switch kind {
        case .basic: passwordReference
        case .bearer: tokenReference
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4: nil
        }
    }

    public func typedCredential(for reference: SecretReference) -> String? {
        typedCredentials[reference]
    }

    public mutating func setCredential(_ text: String, for reference: SecretReference) {
        typedCredentials[reference] = text
    }

    /// Drops text the person has typed back to what is stored, which leaves nothing to save.
    public mutating func discardCredentials(where isStored: (SecretReference, String) -> Bool) {
        typedCredentials = typedCredentials.filter { !isStored($0.key, $0.value) }
    }

    /// A password is always saved, because Basic can send a username alone. An empty token is not, because a header
    /// can't send one, and a credential with no value is reported rather than sent.
    public func credentialWrites(heldBy saved: Auth) -> [CredentialWrite] {
        switch kind {
        case .basic:
            if let text = typedCredentials[passwordReference] {
                return [CredentialWrite(reference: passwordReference, value: text)]
            }
            return saved.secretReferences.contains(passwordReference)
                ? []
                : [CredentialWrite(reference: passwordReference, value: "")]
        case .bearer:
            return typedCredentials[tokenReference].map { text in
                [CredentialWrite(reference: tokenReference, value: text.isEmpty ? nil : text)]
            } ?? []
        case .inherit, .none, .apiKey, .digest, .oauth2, .awsSigV4:
            return []
        }
    }

    /// Typing for a kind that isn't chosen is no change, because Save won't write it.
    public func hasSameContent(as other: AuthDraft) -> Bool {
        requestAuth == other.requestAuth && chosenCredential == other.chosenCredential
    }

    private var chosenCredential: String? {
        credentialReference.flatMap { typedCredentials[$0] }
    }

}
