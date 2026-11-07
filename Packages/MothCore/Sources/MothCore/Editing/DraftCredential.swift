//  DraftCredential.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// One credential under `AuthDraft`'s rules, for a draft that holds several.
nonisolated struct DraftCredential: Sendable {

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

    mutating func rebase(onto saved: DraftCredential) {
        stored = saved.stored
        if new == stored {
            new = SecretReference()
        }
    }

}
