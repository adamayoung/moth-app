//  AuthDraftAPIKeyTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore
import Testing

struct AuthDraftAPIKeyTests {

    private let value = SecretReference(identifier: "value")

    private var stored: Auth {
        .apiKey(APIKeyAuth(name: "X-Key", value: value, location: .query))
    }

    private func requestAPIKey(of draft: AuthDraft) throws -> APIKeyAuth {
        guard case .apiKey(let apiKey) = draft.requestAuth else {
            Issue.record("Expected an API key, got \(draft.requestAuth)")
            throw AuthKindMismatch()
        }
        return apiKey
    }

    private struct AuthKindMismatch: Error {}

    @Test("A stored key fills the fields")
    func fillsTheFields() {
        let draft = AuthDraft(stored)

        #expect(draft.kind == .apiKey)
        #expect(draft.apiKeyName == "X-Key")
        #expect(draft.apiKeyLocation == .query)
        #expect(draft.apiKeyValueReference == value)
        #expect(draft.credentialReference == value)
    }

    @Test("A new key goes in a header, with no name")
    func newKeyDefaults() throws {
        var draft = AuthDraft(.none)

        draft.kind = .apiKey

        let apiKey = try requestAPIKey(of: draft)
        #expect(apiKey.name.isEmpty)
        #expect(apiKey.location == .header)
    }

    @Test("A typed value is written under the reference the row holds, and never reaches it")
    func typedValue() throws {
        var draft = AuthDraft(.none)
        draft.kind = .apiKey
        draft.apiKeyName = "X-Key"
        draft.setCredential("s3cret", for: draft.apiKeyValueReference)

        let apiKey = try requestAPIKey(of: draft)

        #expect(draft.typedCredential(for: draft.apiKeyValueReference) == "s3cret")
        #expect(draft.credentialWrites() == [CredentialWrite(reference: apiKey.value, value: "s3cret")])
        #expect(!String(describing: draft.requestAuth).contains("s3cret"))
    }

    @Test("A changed value goes under a new reference, so a Save that fails changes nothing stored")
    func changedValueMoves() throws {
        var draft = AuthDraft(stored)
        draft.setCredential("new", for: value)

        let apiKey = try requestAPIKey(of: draft)

        #expect(apiKey.value != value)
        #expect(draft.credentialWrites() == [CredentialWrite(reference: apiKey.value, value: "new")])
    }

    @Test("An untouched value writes nothing")
    func untouchedValue() {
        #expect(AuthDraft(stored).credentialWrites().isEmpty)
        #expect(AuthDraft(stored).requestAuth == stored)
    }

    @Test("An empty value saves nothing, so a send reports it as missing")
    func emptyValue() {
        var draft = AuthDraft(.none)
        draft.kind = .apiKey
        draft.setCredential("", for: draft.apiKeyValueReference)

        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("A value typed back to what is stored leaves nothing to save")
    func discardsAMatchingValue() {
        var draft = AuthDraft(stored)
        draft.setCredential("same", for: value)

        draft.discardCredentials { $0 == value && $1 == "same" }

        #expect(draft.typedCredential(for: value) == nil)
        #expect(draft.hasSameContent(as: AuthDraft(stored)))
    }

    @Test("The name, the location and a typed value are each part of the content")
    func content() {
        var renamed = AuthDraft(stored)
        renamed.apiKeyName = "X-Other"
        var moved = AuthDraft(stored)
        moved.apiKeyLocation = .header
        var typed = AuthDraft(stored)
        typed.setCredential("new", for: value)

        #expect(!renamed.hasSameContent(as: AuthDraft(stored)))
        #expect(!moved.hasSameContent(as: AuthDraft(stored)))
        #expect(!typed.hasSameContent(as: AuthDraft(stored)))
    }

    @Test("Typing a value for another kind is no change")
    func typedForAnotherKind() {
        var draft = AuthDraft(.none)
        draft.setCredential("typed", for: draft.apiKeyValueReference)

        #expect(draft.hasSameContent(as: AuthDraft(.none)))
    }

    @Test("Choosing another kind and back keeps the key")
    func survivesASwitch() {
        var draft = AuthDraft(stored)

        draft.kind = .bearer
        draft.kind = .apiKey

        #expect(draft.requestAuth == stored)
    }

    @Test("Following what is saved takes its fields and drops what was typed")
    func follows() throws {
        let newer = SecretReference(identifier: "newer")
        var draft = AuthDraft(stored)
        draft.apiKeyName = "X-Other"
        draft.setCredential("typed", for: value)

        draft.follow(AuthDraft(.apiKey(APIKeyAuth(name: "X-Saved", value: newer, location: .header))))

        let apiKey = try requestAPIKey(of: draft)
        #expect(apiKey == APIKeyAuth(name: "X-Saved", value: newer, location: .header))
        #expect(draft.credentialWrites().isEmpty)
    }

    @Test("Rebasing an edited key takes the row's reference, and keeps its name and location")
    func rebases() throws {
        let newer = SecretReference(identifier: "newer")
        var draft = AuthDraft(stored)
        draft.apiKeyName = "X-Other"
        draft.apiKeyLocation = .header

        draft.rebaseCredentials(onto: AuthDraft(.apiKey(APIKeyAuth(name: "X-Key", value: newer, location: .query))))

        #expect(try requestAPIKey(of: draft) == APIKeyAuth(name: "X-Other", value: newer, location: .header))
    }

    @Test("Rebasing onto a row that holds a reference this draft minted mints another, so nothing writes over it")
    func rebasingNeverReusesAHeldReference() throws {
        var draft = AuthDraft(stored)
        draft.setCredential("first", for: value)
        let saved = AuthDraft(draft.requestAuth)

        draft.rebaseCredentials(onto: saved)
        draft.setCredential("second", for: draft.apiKeyValueReference)

        let write = try #require(draft.credentialWrites().first)
        #expect(write.reference != saved.apiKeyValueReference)
    }

}
