//  RequestDraftsSaveTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestDraftsSaveTests: RequestDraftsTesting {

    private struct WriteRefused: Error {}

    private let token = SecretReference(identifier: "token")
    private let newerToken = SecretReference(identifier: "newer-token")

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
        let drafts = RequestDrafts(secretStore: secretStore) { _, _, _ in throw WriteRefused() }
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
