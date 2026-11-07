//  AWSSigV4Draft.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Follows `AuthDraft`'s rules for a credential, for each of the three this auth holds.
public nonisolated struct AWSSigV4Draft: Sendable {

    private struct Credential: Sendable {

        var stored: SecretReference?
        var new = SecretReference()
        var typed: String?

        var reference: SecretReference {
            stored ?? new
        }

        var saved: SecretReference {
            typed == nil ? reference : new
        }

        /// A cleared field has no reference at all, unlike a required credential, whose row reports it as missing.
        var savedIfSet: SecretReference? {
            guard let typed else {
                return stored
            }
            return typed.isEmpty ? nil : new
        }

        var write: CredentialWrite? {
            guard let typed, !typed.isEmpty else {
                return nil
            }
            return CredentialWrite(reference: new, value: typed)
        }

        mutating func rebase(onto saved: Credential) {
            stored = saved.stored
            if new == stored {
                new = SecretReference()
            }
        }

    }

    public var region = ""
    public var service = ""
    private var accessKey = Credential()
    private var secretKey = Credential()
    private var sessionToken = Credential()

    init() {}

    init(_ auth: AWSSigV4Auth) {
        self.region = auth.region
        self.service = auth.service
        accessKey.stored = auth.accessKeyID
        secretKey.stored = auth.secretAccessKey
        sessionToken.stored = auth.sessionToken
    }

    public var accessKeyReference: SecretReference {
        accessKey.reference
    }

    public var secretKeyReference: SecretReference {
        secretKey.reference
    }

    public var sessionTokenReference: SecretReference {
        sessionToken.reference
    }

    var auth: AWSSigV4Auth {
        AWSSigV4Auth(
            accessKeyID: accessKey.saved,
            secretAccessKey: secretKey.saved,
            sessionToken: sessionToken.savedIfSet,
            region: region,
            service: service
        )
    }

    var references: [SecretReference] {
        [accessKeyReference, secretKeyReference, sessionTokenReference]
    }

    var writes: [CredentialWrite] {
        [accessKey, secretKey, sessionToken].compactMap(\.write)
    }

    var typedText: [String?] {
        [accessKey, secretKey, sessionToken].map(\.typed)
    }

    private var credentialPaths: [WritableKeyPath<Self, Credential>] {
        [\.accessKey, \.secretKey, \.sessionToken]
    }

    func typedCredential(for reference: SecretReference) -> String? {
        credentialPaths.first { self[keyPath: $0].reference == reference }.flatMap { self[keyPath: $0].typed }
    }

    mutating func setCredential(_ text: String, for reference: SecretReference) {
        if let path = credentialPaths.first(where: { self[keyPath: $0].reference == reference }) {
            self[keyPath: path].typed = text
        }
    }

    mutating func discardCredentials(where isStored: (SecretReference, String) -> Bool) {
        for path in credentialPaths {
            let credential = self[keyPath: path]
            if let typed = credential.typed, isStored(credential.reference, typed) {
                self[keyPath: path].typed = nil
            }
        }
    }

    mutating func follow(_ saved: AWSSigV4Draft) {
        region = saved.region
        service = saved.service
        for path in credentialPaths {
            self[keyPath: path].typed = nil
        }
    }

    mutating func rebaseCredentials(onto saved: AWSSigV4Draft) {
        for path in credentialPaths {
            self[keyPath: path].rebase(onto: saved[keyPath: path])
        }
    }

}
