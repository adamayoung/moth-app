//  AuthDraftDigestTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct AuthDraftDigestTests {

    private let password = SecretReference(identifier: "password")

    private var stored: Auth {
        .digest(DigestAuth(username: "ada", password: password))
    }

    private func requestDigest(of draft: AuthDraft) throws -> DigestAuth {
        guard case .digest(let digest) = draft.requestAuth else {
            Issue.record("Expected Digest auth, got \(draft.requestAuth)")
            throw AuthKindMismatch()
        }
        return digest
    }

    private struct AuthKindMismatch: Error {}

    @Test("Digest is offered, before AWS Signature")
    func offered() {
        #expect(AuthDraft(.none).kinds == [.inherit, .none, .basic, .bearer, .apiKey, .digest, .awsSigV4])
    }

    @Test("A stored Digest fills its fields, and has nothing to save")
    func fillsTheFields() {
        let draft = AuthDraft(stored)

        #expect(draft.kind == .digest)
        #expect(draft.kinds == AuthKind.editable)
        #expect(draft.username == "ada")
        #expect(draft.passwordReference == password)
        #expect(draft.credentialReferences == [password])
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("A typed password is written under the reference the row holds, and never reaches it")
    func typedPassword() throws {
        var draft = AuthDraft(stored)
        draft.setCredential("s3cret", for: draft.passwordReference)

        let digest = try requestDigest(of: draft)

        #expect(digest.password != password)
        #expect(draft.credentialWrites() == [CredentialWrite(reference: digest.password, value: "s3cret")])
        #expect(!String(describing: draft.requestAuth).contains("s3cret"))
    }

    @Test("A new Digest saves an empty password, because it can send a username alone")
    func newDigestSavesAPassword() throws {
        var draft = AuthDraft(.none)
        draft.kind = .digest
        draft.username = "ada"

        let digest = try requestDigest(of: draft)

        #expect(digest.username == "ada")
        #expect(draft.credentialWrites() == [CredentialWrite(reference: digest.password, value: "")])
    }

    @Test("Switching between Basic and Digest keeps the username and what was typed")
    func sharesBasicsFields() throws {
        var draft = AuthDraft(.none)
        draft.kind = .basic
        draft.username = "ada"
        draft.setCredential("s3cret", for: draft.passwordReference)

        draft.kind = .digest

        let digest = try requestDigest(of: draft)
        #expect(digest.username == "ada")
        #expect(draft.credentialWrites() == [CredentialWrite(reference: digest.password, value: "s3cret")])
    }

    @Test("Following a saved Digest takes its username and drops what was typed")
    func follows() {
        var draft = AuthDraft(.none)
        draft.kind = .digest
        draft.username = "grace"
        draft.setCredential("typed", for: draft.passwordReference)

        draft.follow(AuthDraft(stored))

        #expect(draft.requestAuth == stored)
        #expect(draft.typedCredential(for: draft.passwordReference) == nil)
    }

}
