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
struct RequestDraftsCredentialTests {

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
    private let newerToken = SecretReference(identifier: "newer-token")

    private func bearer(_ token: SecretReference) -> Auth {
        .bearer(BearerAuth(token: token))
    }

    private func stored(
        _ request: Request,
        secretStore: any SecretStore
    ) throws -> (DataModel, RequestDrafts) {
        let dataModel = try DataModel.inMemory(
            seed: Workspace(collections: [RequestCollection(name: "API", children: [
                CollectionItem(sortOrder: 0, node: .request(request))
            ])])
        )
        let drafts = RequestDrafts(writer: dataModel.writer, secretStore: secretStore)
        drafts.savedRequestDidChange(request)
        return (dataModel, drafts)
    }

    private func savedRequest(_ id: Request.ID, in dataModel: DataModel) throws -> RequestModel {
        try #require(ModelContext(dataModel.container).fetch(RequestModel.withID(id)).first)
    }

    /// Bounded, because a Save that never reaches the store would otherwise hold the machine-wide build lock for ever.
    private func waitUntilHolding(_ store: HoldingSecretStore) async {
        for _ in 0 ..< 100_000 {
            if await store.isHoldingASave {
                return
            }
            await Task.yield()
        }
        Issue.record("The Save never reached the secret store")
    }

    /// Every stored field of the row as text, so a credential can't hide in one a test forgot to name.
    private func storedText(of row: RequestModel) -> String {
        let fields = [row.queryParametersData, row.pathParametersData, row.headersData, row.bodyData, row.authData]
        return fields.compactMap(\.self).map { String(decoding: $0, as: UTF8.self) }.joined()
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

        #expect(valuesAtWrite == [token.identifier: "typed"])
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

    @Test("After a Save the field shows what was saved, with nothing edited")
    func saveShowsTheSavedValue() async {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("typed", for: token) }

        #expect(await drafts.save(request.id))

        #expect(drafts.credential(token, in: request.id) == .available("typed"))
        #expect(drafts.draft(for: request.id)?.auth.typedCredential(for: token) == nil)
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

    @Test("Clearing a token removes the stored value")
    func clearingATokenRemovesIt() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        await drafts.loadCredential(token, in: request.id)
        drafts.update(request.id) { $0.auth.setCredential("", for: token) }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values.isEmpty)
        #expect(drafts.credential(token, in: request.id) == .notYetAvailable)
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

    @Test("An unsupported body and auth survive a Save through the real writer")
    func unsupportedKindsSurviveSave() async throws {
        let auth = Auth.apiKey(APIKeyAuth(name: "X-Key", value: token, location: .header))
        let body = RequestBody.binary(filePath: "/tmp/a.bin")
        let request = Request(name: "Request", body: body, auth: auth)
        let (dataModel, drafts) = try stored(request, secretStore: RecordingSecretStore())
        drafts.update(request.id) { $0.url = "https://example.com" }

        #expect(await drafts.save(request.id))

        let saved = try savedRequest(request.id, in: dataModel).asDomain()
        #expect(saved.urlTemplate == "https://example.com")
        #expect(saved.body == body)
        #expect(saved.auth == auth)
    }

    @Test("A replaced credential leaves the secret store once the row has moved on")
    func replacedCredentialIsRemoved() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let request = Request(name: "Request", auth: bearer(token))
        let (_, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.auth.kind = .none }

        #expect(await drafts.save(request.id))

        #expect(secretStore.values.isEmpty)
    }

    @Test("A credential stays in the secret store if the row can't be written")
    func failedWriteKeepsTheCredential() async {
        let secretStore = RecordingSecretStore()
        secretStore.save("stored", for: token.identifier)
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in throw KeychainRefused() }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.kind = .none }

        #expect(await !drafts.save(request.id))

        #expect(secretStore.values == [token.identifier: "stored"])
        #expect(drafts.isEdited(request.id))
    }

    @Test("A Save refused for a newer credential keeps the draft, and the delivery that follows lets it through")
    func refusedSaveRecovers() async throws {
        let secretStore = RecordingSecretStore()
        let request = Request(name: "Request", auth: bearer(token))
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.url = "https://example.com/mine" }
        var synced = request
        synced.auth = bearer(newerToken)
        try await dataModel.writer.updateRequest(
            request.id,
            with: RequestEdit(synced),
            replacing: bearer(token)
        )

        #expect(await !drafts.save(request.id))
        #expect(drafts.draft(for: request.id)?.url == "https://example.com/mine")
        #expect(drafts.isEdited(request.id))

        drafts.savedRequestDidChange(synced)

        #expect(await drafts.save(request.id))
        let saved = try savedRequest(request.id, in: dataModel).asDomain()
        #expect(saved.urlTemplate == "https://example.com/mine")
        #expect(saved.auth == bearer(newerToken))
    }

    @Test("A body and auth nobody touched follow a sync, under a draft edited elsewhere")
    func untouchedFieldsFollowASync() {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.url = "https://example.com/mine" }
        var synced = request
        synced.body = .raw(content: "{}", contentType: "application/json")
        synced.auth = bearer(token)

        drafts.savedRequestDidChange(synced)

        let draft = drafts.draft(for: request.id)
        #expect(draft?.url == "https://example.com/mine")
        #expect(draft?.edit.body == synced.body)
        #expect(draft?.edit.auth == synced.auth)
    }

    @Test("A body and auth someone edited stay, when a sync changes them")
    func editedFieldsStayThroughASync() {
        let drafts = RequestDrafts(secretStore: RecordingSecretStore()) { _, _, _ in [] }
        let request = Request(name: "Request")
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { draft in
            draft.body.kind = .raw
            draft.body.rawContent = "mine"
            draft.auth.kind = .none
        }
        var synced = request
        synced.body = .raw(content: "theirs", contentType: "text/plain")
        synced.auth = bearer(token)

        drafts.savedRequestDidChange(synced)

        let draft = drafts.draft(for: request.id)
        #expect(draft?.edit.body == .raw(content: "mine", contentType: "application/json"))
        #expect(draft?.edit.auth == Auth.none)
    }

    @Test("Saves run in order, so a later Save can't be overtaken by an earlier one")
    func savesRunInOrder() async {
        let secretStore = HoldingSecretStore()
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in [] }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("first", for: token) }
        await secretStore.holdNextSave()
        let firstSave = Task { await drafts.save(request.id) }
        await waitUntilHolding(secretStore)

        drafts.update(request.id) { $0.auth.setCredential("second", for: token) }
        let secondSave = Task { await drafts.save(request.id) }
        await Task.yield()
        await secretStore.finishHeldSave()

        #expect(await firstSave.value)
        #expect(await secondSave.value)
        #expect(await secretStore.values == [token.identifier: "second"])
    }

}
