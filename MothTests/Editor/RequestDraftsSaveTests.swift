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

    @Test("An auth edit refused for a newer credential keeps the draft, and the delivery that follows lets it through")
    func refusedSaveRecovers() async throws {
        let secretStore = RecordingSecretStore()
        secretStore.save("newer", for: newerToken.identifier)
        let request = Request(name: "Request", auth: bearer(token))
        let (dataModel, drafts) = try stored(request, secretStore: secretStore)
        drafts.update(request.id) { $0.auth.kind = .none }
        var synced = request
        synced.auth = bearer(newerToken)
        try await dataModel.writer.updateRequest(
            request.id,
            with: RequestEdit(synced),
            from: RequestEdit(request)
        )

        #expect(await !drafts.save(request.id))
        #expect(drafts.isEdited(request.id))
        #expect(secretStore.values == [newerToken.identifier: "newer"])

        drafts.savedRequestDidChange(synced)

        #expect(await drafts.save(request.id))
        #expect(try savedRequest(request.id, in: dataModel).asDomain().auth == Auth.none)
        #expect(secretStore.values.isEmpty)
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
        var written: Auth?
        let drafts = RequestDrafts(secretStore: secretStore) { _, edit, _ in
            written = edit.auth
            return []
        }
        let request = Request(name: "Request", auth: bearer(token))
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.auth.setCredential("first", for: token) }
        secretStore.holdNextSave()
        let firstSave = Task { await drafts.save(request.id) }
        await secretStore.waitUntilHolding()

        drafts.update(request.id) { $0.auth.setCredential("second", for: token) }
        let secondSave = Task { await drafts.save(request.id) }
        await Task.yield()
        secretStore.finishHeldSave()

        #expect(await firstSave.value)
        #expect(await secondSave.value)
        guard case .bearer(let saved) = written else {
            Issue.record("The last Save should have written Bearer auth")
            return
        }
        #expect(secretStore.values[saved.token.identifier] == "second")
    }

}
