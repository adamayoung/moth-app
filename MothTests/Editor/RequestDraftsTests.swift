//  RequestDraftsTests.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import Moth
import MothCore
import SwiftData
import Testing

@MainActor
struct RequestDraftsTests {

    private struct SaveFailed: Error {}

    private let request = Request(name: "List Users", urlTemplate: "https://example.com/users")

    private func loaded(saving save: @escaping RecordedSave = { _, _ in }) -> RequestDrafts {
        let drafts = RequestDrafts(recording: save)
        drafts.savedRequestDidChange(request)
        return drafts
    }

    private func synced(_ url: String) -> Request {
        var synced = request
        synced.urlTemplate = url
        return synced
    }

    @Test("A saved request loads as a draft with no edits")
    func loadsClean() {
        let drafts = loaded()

        #expect(drafts.draft(for: request.id)?.url == request.urlTemplate)
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A request with no draft is not edited")
    func noDraftIsNotEdited() {
        #expect(!RequestDrafts.preview.isEdited(request.id))
    }

    @Test("A change marks the request edited, and undoing it clears that")
    func changeMarksEdited() {
        let drafts = loaded()

        drafts.update(request.id) { $0.url += "/more" }
        #expect(drafts.isEdited(request.id))

        drafts.update(request.id) { $0.url = request.urlTemplate }
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A sync change follows a draft with no edits")
    func syncFollowsCleanDraft() {
        let drafts = loaded()

        drafts.savedRequestDidChange(synced("https://example.com/synced"))

        #expect(drafts.draft(for: request.id)?.url == "https://example.com/synced")
        #expect(!drafts.isEdited(request.id))
    }

    @Test("A sync change leaves an edited draft alone, and the next Save wins")
    func syncLeavesEditedDraft() async {
        var saved: RequestEdit?
        let drafts = loaded { _, edit in saved = edit }
        drafts.update(request.id) { $0.url = "https://example.com/mine" }

        drafts.savedRequestDidChange(synced("https://example.com/theirs"))

        #expect(drafts.draft(for: request.id)?.url == "https://example.com/mine")
        #expect(drafts.isEdited(request.id))

        #expect(await drafts.save(request.id))
        #expect(saved?.urlTemplate == "https://example.com/mine")
    }

    @Test("Save writes the draft, clears the edits and shows the stored URL")
    func saveClearsEdits() async {
        var saved: (Request.ID, RequestEdit)?
        let drafts = loaded { id, edit in saved = (id, edit) }
        drafts.update(request.id) { $0.url = "https://example.com/users?flag" }

        #expect(await drafts.save(request.id))

        #expect(saved?.0 == request.id)
        #expect(saved?.1.queryParameters.map(\.key) == ["flag"])
        #expect(!drafts.isEdited(request.id))
        #expect(drafts.draft(for: request.id)?.url == "https://example.com/users?flag=")
    }

    @Test("A store delivery that lands before Save returns leaves nothing edited")
    func deliveryDuringSave() async {
        var drafts: RequestDrafts?
        let delivered = { (edit: RequestEdit) in
            var request = request
            request.urlTemplate = edit.urlTemplate
            request.queryParameters = edit.queryParameters
            drafts?.savedRequestDidChange(request)
        }
        let model = loaded { _, edit in delivered(edit) }
        drafts = model
        model.update(request.id) { $0.url = "https://example.com/users?a=b+c" }

        #expect(await model.save(request.id))

        #expect(!model.isEdited(request.id))
        #expect(model.draft(for: request.id)?.url == "https://example.com/users?a=b%20c")
    }

    @Test("A store delivery after Save leaves nothing edited")
    func deliveryAfterSave() async {
        var saved: RequestEdit?
        let drafts = loaded { _, edit in saved = edit }
        drafts.update(request.id) { $0.url = "https://example.com/users?a=b+c" }
        #expect(await drafts.save(request.id))

        var delivered = request
        delivered.urlTemplate = saved?.urlTemplate ?? ""
        delivered.queryParameters = saved?.queryParameters ?? []
        drafts.savedRequestDidChange(delivered)

        #expect(!drafts.isEdited(request.id))
    }

    @Test("Text typed while a Save is running stays edited")
    func typingDuringSave() async {
        var drafts: RequestDrafts?
        let id = request.id
        let model = loaded { _, _ in drafts?.update(id) { $0.url = "https://example.com/typed" } }
        drafts = model
        model.update(id) { $0.url = "https://example.com/saved" }

        #expect(await model.save(id))

        #expect(model.draft(for: id)?.url == "https://example.com/typed")
        #expect(model.isEdited(id))
    }

    @Test("A failed Save reports it and keeps the draft")
    func failedSave() async {
        let drafts = loaded { _, _ in throw SaveFailed() }
        drafts.update(request.id) { $0.url = "https://example.com/mine" }

        #expect(await !drafts.save(request.id))

        #expect(drafts.draft(for: request.id)?.url == "https://example.com/mine")
        #expect(drafts.isEdited(request.id))
    }

    @Test("Saving with no edits writes nothing")
    func saveWithNoEdits() async {
        var saves = 0
        let drafts = loaded { _, _ in saves += 1 }

        #expect(await drafts.save(request.id))

        #expect(saves == 0)
    }

    @Test("A request that can't be read refuses Save, so a hidden draft can't overwrite what it couldn't show")
    func unreadableRefusesSave() async {
        var saves = 0
        let drafts = loaded { _, _ in saves += 1 }
        drafts.update(request.id) { $0.method = .post }
        #expect(drafts.canSave(request.id))

        drafts.savedRequestIsUnreadable(request.id)

        #expect(!drafts.canSave(request.id))
        #expect(await !drafts.save(request.id))
        #expect(saves == 0)
    }

    @Test("Revert goes to the latest stored value")
    func revertGoesToLatest() {
        let drafts = loaded()
        drafts.update(request.id) { $0.url = "https://example.com/mine" }
        drafts.savedRequestDidChange(synced("https://example.com/theirs"))

        drafts.revert(request.id)

        #expect(drafts.draft(for: request.id)?.url == "https://example.com/theirs")
        #expect(!drafts.isEdited(request.id))
    }

    @Test("The edited count covers edited requests only")
    func editedCount() {
        let other = Request(name: "Other")
        let clean = Request(name: "Clean")
        let drafts = loaded()
        drafts.savedRequestDidChange(other)
        drafts.savedRequestDidChange(clean)
        #expect(drafts.editedRequestCount == 0)

        drafts.update(request.id) { $0.method = .post }
        drafts.update(other.id) { $0.method = .post }

        #expect(drafts.editedRequestCount == 2)
    }

    @Test("A request that leaves the store drops its draft")
    func requestLeavesStore() {
        let other = Request(name: "Other")
        let drafts = loaded()
        drafts.savedRequestDidChange(other)
        drafts.update(request.id) { $0.method = .post }
        drafts.update(other.id) { $0.method = .post }

        drafts.keepRequests([other.id])

        #expect(drafts.draft(for: request.id) == nil)
        #expect(drafts.editedRequestCount == 1)
    }

    @Test("A request that can't be read shows as unreadable until a delivery can be")
    func unreadable() {
        let drafts = RequestDrafts.preview

        drafts.savedRequestIsUnreadable(request.id)
        #expect(drafts.isUnreadable(request.id))
        #expect(drafts.draft(for: request.id) == nil)

        drafts.savedRequestDidChange(request)
        #expect(!drafts.isUnreadable(request.id))
    }

    @Test("Save through the writer keeps a rename made in the sidebar")
    func saveKeepsRename() async throws {
        let dataModel = try DataModel.inMemory(seed: Workspace(collections: [
            RequestCollection(name: "API", children: [CollectionItem(sortOrder: 0, node: .request(request))])
        ]))
        let drafts = RequestDrafts(writer: dataModel.writer, secretStore: InMemorySecretStore())
        drafts.savedRequestDidChange(request)
        drafts.update(request.id) { $0.method = .post }
        try await dataModel.writer.rename(.request(request.id), to: "Renamed")

        #expect(await drafts.save(request.id))

        let id = request.id
        let row = try #require(
            ModelContext(dataModel.container).fetch(RequestModel.withID(id)).first
        )
        #expect(row.name == "Renamed")
        #expect(row.methodRawValue == "POST")
    }

}
