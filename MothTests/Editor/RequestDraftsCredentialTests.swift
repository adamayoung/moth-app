//  RequestDraftsCredentialTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestDraftsCredentialTests: RequestDraftsTesting {

    private struct KeychainRefused: Error {}

    private struct RefusingSecretStore: SecretStore {
        func save(_: String, for _: String) async throws {
            throw KeychainRefused()
        }

        func value(for _: String) async throws -> String? {
            nil
        }

        func removeValue(for _: String) async throws {
            throw KeychainRefused()
        }
    }

    private let token = SecretReference(identifier: "token")

    /// Every stored field of the row as text, so a credential can't hide in one a test forgot to name.
    private func storedText(of row: RequestModel) -> String {
        let fields = [row.queryParametersData, row.pathParametersData, row.headersData, row.bodyData, row.authData]
        return fields.compactMap(\.self).compactMap { String(bytes: $0, encoding: .utf8) }.joined()
            + row.name + row.urlTemplate
    }

    @Test("A typed token reaches the secret store under its reference, and no row holds it")
    func tokenReachesTheSecretStore() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request")
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { draft in
            draft.auth.kind = .bearer
            draft.auth.setCredential("s3cret-token", for: draft.auth.tokenReference)
        }
        let reference = try #require(drafts.draft(for: request.id)?.auth.tokenReference)

        #expect(await drafts.save(request.id))

        #expect(secretStore.values == [reference.identifier: "s3cret-token"])
        let row = try savedRequest(request.id, in: dataModel)
        #expect(try row.asDomain().auth == bearer(reference))
        #expect(!storedText(of: row).contains("s3cret-token"))
    }

    @Test("A typed API key value reaches the secret store under its reference, and no row holds it")
    func apiKeyValueReachesTheSecretStore() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request")
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { draft in
            draft.auth.kind = .apiKey
            draft.auth.apiKeyName = "X-Key"
            draft.auth.apiKeyLocation = .query
            draft.auth.setCredential("s3cret-key", for: draft.auth.apiKeyValueReference)
        }
        let reference = try #require(drafts.draft(for: request.id)?.auth.apiKeyValueReference)

        #expect(await drafts.save(request.id))

        #expect(secretStore.values == [reference.identifier: "s3cret-key"])
        let row = try savedRequest(request.id, in: dataModel)
        #expect(try row.asDomain().auth == .apiKey(APIKeyAuth(name: "X-Key", value: reference, location: .query)))
        #expect(!storedText(of: row).contains("s3cret-key"))
    }

    @Test("A typed password reaches the secret store under its reference, and no row holds it")
    func passwordReachesTheSecretStore() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request")
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { draft in
            draft.auth.kind = .basic
            draft.auth.username = "ada"
            draft.auth.setCredential("s3cret-password", for: draft.auth.passwordReference)
        }
        let reference = try #require(drafts.draft(for: request.id)?.auth.passwordReference)

        #expect(await drafts.save(request.id))

        #expect(secretStore.values == [reference.identifier: "s3cret-password"])
        let row = try savedRequest(request.id, in: dataModel)
        #expect(try row.asDomain().auth == .basic(BasicAuth(username: "ada", password: reference)))
        #expect(!storedText(of: row).contains("s3cret-password"))
    }

    @Test("The value is stored before the row that refers to it")
    func valueComesFirst() async {
        let secretStore = RecordingSecretStore()
        var valuesAtWrite: [String: String]?
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in
            valuesAtWrite = secretStore.values
            return []
        }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }

        #expect(await drafts.save(request.id))

        #expect(valuesAtWrite?.values.contains("typed") == true)
    }

    @Test("A value the store refuses stops the Save, so no row refers to nothing")
    func refusedValueStopsTheSave() async {
        var saves = 0
        let drafts = RequestDrafts(secretStore: RefusingSecretStore()) { _, _, _ in
            saves += 1
            return []
        }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }

        #expect(await !drafts.save(request.id))

        #expect(saves == 0)
        #expect(drafts.isEdited(request.id))
    }

    @Test("A Save that changes no credential writes none")
    func unchangedCredentialWritesNothing() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request", auth: bearer(token))
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.url = "https://example.com" }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values.isEmpty)
        #expect(try savedRequest(request.id, in: dataModel).urlTemplate == "https://example.com")
    }

    @Test("A credential that loads fills its field and leaves nothing edited")
    func loadingFillsTheField() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        #expect(drafts.credential(token, in: request.id) == .loading)

        await drafts.loadCredential(token, in: request.id)

        #expect(drafts.credential(token, in: request.id) == .available("stored"))
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A credential with no stored value is not yet available, and can still be typed")
    func missingCredentialCanBeTyped() async {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)

        await drafts.loadCredential(token, in: request.id)
        #expect(drafts.credential(token, in: request.id) == .notYetAvailable)

        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }
        #expect(drafts.isEdited(request.id))

        drafts.update(request.id) { $0.auth.setCredential("", for: token) }
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A read that fails shows as not yet available")
    func failedReadIsNotYetAvailable() async {
        let drafts = RequestDrafts(secretStore: FailingReadStore()) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)

        await drafts.loadCredential(token, in: request.id)

        #expect(drafts.credential(token, in: request.id) == .notYetAvailable)
    }

    private struct FailingReadStore: SecretStore {
        func save(_: String, for _: String) async throws {}

        func value(for _: String) async throws -> String? {
            throw KeychainRefused()
        }

        func removeValue(for _: String) async throws {}
    }

    @Test("A new credential starts empty, with nothing to wait for")
    func newCredentialStartsEmpty() throws {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)

        drafts.update(request.id) { $0.auth.kind = .bearer }

        let reference = try #require(drafts.draft(for: request.id)?.auth.tokenReference)
        #expect(drafts.credential(reference, in: request.id) == .available(""))
    }

    @Test("Typing a stored credential back in leaves nothing edited")
    func typingTheStoredValueIsNoChange() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        await drafts.loadCredential(token, in: request.id)

        drafts.update(request.id) { $0.auth.setCredential("other", for: token) }
        #expect(drafts.isEdited(request.id))

        drafts.update(request.id) { $0.auth.setCredential("stored", for: token) }
        #expect(!drafts.isEdited(request.id))
    }

    @Test("After a Save the field shows what was saved under its new reference, with nothing edited")
    func saveShowsTheSavedValue() async throws {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }

        #expect(await drafts.save(request.id))

        let reference = try #require(drafts.draft(for: request.id)?.auth.tokenReference)
        #expect(reference != token)
        #expect(drafts.credential(reference, in: request.id) == .available("typed"))
        #expect(drafts.draft(for: request.id)?.auth.typedCredential(for: reference) == nil)
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A new Bearer auth saved with no token settles on not yet available, rather than loading for ever")
    func emptyTokenSettles() async throws {
        let request = Request(name: "Request")
        let (_, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.auth.kind = .bearer }
        let reference = try #require(drafts.draft(for: request.id)?.auth.tokenReference)

        #expect(await drafts.save(request.id))

        #expect(drafts.credential(reference, in: request.id) == .notYetAvailable)
    }

    @Test("Clearing a token removes the stored value once the row has moved on")
    func clearingATokenRemovesIt() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let request = Request(name: "Request", auth: bearer(token))
        let (_, drafts) = try stored(request, secretStore: secretStore)
        await drafts.loadCredential(token, in: request.id)
        drafts.update(request.id) { $0.auth.setCredential("", for: token) }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values.isEmpty)
        let reference = try #require(drafts.draft(for: request.id)?.auth.tokenReference)
        #expect(drafts.credential(reference, in: request.id) == .notYetAvailable)
    }

    @Test("Revert drops a typed credential")
    func revertDropsTyping() {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }

        drafts.revert(request.id)

        #expect(drafts.draft(for: request.id)?.auth.typedCredential(for: token) == nil)
        #expect(!drafts.isEdited(request.id))
    }

}
