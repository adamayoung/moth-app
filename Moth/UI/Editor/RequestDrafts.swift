//  RequestDrafts.swift
//  Moth
//
//  Copyright © 2026 Adam Young.

import MothCore
import Observation
import OSLog

/// One for the app, keyed by request, because the quit alert has no view in reach and counts requests across windows.
/// Drafts stay in memory, so closing a window keeps them and quitting asks first.
@Observable
final class RequestDrafts {

    /// Takes the edit and what it started from, and returns the references the write leaves unheld.
    typealias Save = @MainActor (Request.ID, RequestEdit, RequestEdit) async throws -> Set<SecretReference>

    private struct Entry {

        var saved: RequestDraft
        var draft: RequestDraft
        var credentials = StoredCredentials()

        var isEdited: Bool {
            !draft.hasSameContent(as: saved)
        }

        mutating func discardCredentialsMatchingStore() {
            draft.auth.discardCredentials(matching: credentials, heldBy: saved.auth.requestAuth)
        }

        /// A sync never takes what was typed, but a body or auth nobody touched follows it, and an edited auth moves to
        /// the references the row now holds, because a Save from the old ones would release the new.
        mutating func moveSaved(to newSaved: RequestDraft) {
            var body = draft.body
            var auth = draft.auth
            if body.hasSameContent(as: saved.body) {
                body.follow(newSaved.body)
            }
            if auth.hasSameContent(as: saved.auth) {
                auth.follow(newSaved.auth)
            } else {
                auth.rebaseCredentials(onto: newSaved.auth)
            }
            if !isEdited {
                draft = newSaved
            }
            draft.body = body
            draft.auth = auth
            saved = newSaved
        }

    }

    private var entries: [Request.ID: Entry] = [:]
    private var unreadable: Set<Request.ID> = []
    private let secretStore: any SecretStore
    private let saveEdit: Save
    private let writes = WriteQueue()

    init(secretStore: any SecretStore, save: @escaping Save) {
        self.secretStore = secretStore
        self.saveEdit = save
    }

    convenience init(writer: StoreWriter, secretStore: any SecretStore) {
        self.init(secretStore: secretStore) { id, edit, base in
            try await writer.updateRequest(id, with: edit, from: base)
        }
    }

    /// New on every use, because previews share one process and one would otherwise show another's drafts.
    static var preview: RequestDrafts {
        RequestDrafts(secretStore: InMemorySecretStore()) { _, _, _ in [] }
    }

    var editedRequestCount: Int {
        entries.values.count(where: \.isEdited)
    }

    func draft(for id: Request.ID) -> RequestDraft? {
        entries[id]?.draft
    }

    func isEdited(_ id: Request.ID) -> Bool {
        entries[id]?.isEdited ?? false
    }

    /// A row that can't be read may hold fields this build can't see, and a Save would overwrite them.
    func canSave(_ id: Request.ID) -> Bool {
        isEdited(id) && !isUnreadable(id)
    }

    func isUnreadable(_ id: Request.ID) -> Bool {
        unreadable.contains(id)
    }

    func credential(_ reference: SecretReference, in id: Request.ID) -> SecretValue {
        guard let entry = entries[id] else {
            return .loading
        }
        return entry.credentials.value(of: reference, heldBy: entry.saved.auth.requestAuth)
    }

    func loadCredential(_ reference: SecretReference, in id: Request.ID) async {
        await writes.run { await self.readCredential(reference, in: id) }
    }

    func update(_ id: Request.ID, _ change: (inout RequestDraft) -> Void) {
        guard var entry = entries[id] else {
            return
        }
        change(&entry.draft)
        entry.discardCredentialsMatchingStore()
        entries[id] = entry
    }

    /// Moves `saved` under an edited draft, so a sync never takes what was typed, Revert goes to what is stored now,
    /// and the next Save wins.
    func savedRequestDidChange(_ request: Request) {
        unreadable.remove(request.id)
        let saved = RequestDraft(request)
        guard var entry = entries[request.id] else {
            entries[request.id] = Entry(saved: saved, draft: saved)
            return
        }
        guard !saved.hasSameContent(as: entry.saved) else {
            return
        }
        entry.moveSaved(to: saved)
        entries[request.id] = entry
    }

    func savedRequestIsUnreadable(_ id: Request.ID) {
        unreadable.insert(id)
    }

    /// Returns whether the draft reached the store. Shows the stored form afterwards, so `?flag` reads `?flag=`, unless
    /// the person typed on during the save.
    func save(_ id: Request.ID) async -> Bool {
        await writes.run { await self.writeDraft(id) }
    }

    private func writeDraft(_ id: Request.ID) async -> Bool {
        guard !isUnreadable(id) else {
            return false
        }
        guard let entry = entries[id], entry.isEdited else {
            return true
        }
        let edit = entry.draft.edit
        let base = entry.saved.edit
        let credentialWrites = entry.draft.auth.credentialWrites()
        do {
            let released = try await secretStore.commit(credentialWrites) {
                try await saveEdit(id, edit, base)
            }
            entries[id]?.credentials.forget(released)
        } catch {
            Logger.editor.error("Saving a request failed: \(String(describing: error), privacy: .private)")
            return false
        }
        for write in credentialWrites {
            entries[id]?.credentials.record(write.value, for: write.reference)
        }
        await finishSave(of: edit, from: entry.draft, heldBefore: base.auth, in: id)
        return true
    }

    private func finishSave(
        of edit: RequestEdit,
        from draft: RequestDraft,
        heldBefore held: Auth,
        in id: Request.ID
    ) async {
        let saved = RequestDraft(edit)
        let isUnchanged = entries[id]?.draft.hasSameContent(as: draft) ?? false
        entries[id]?.saved = saved
        if isUnchanged {
            entries[id]?.draft = saved
        } else {
            entries[id]?.draft.auth.rebaseCredentials(onto: saved.auth)
        }
        entries[id]?.discardCredentialsMatchingStore()
        for reference in saved.auth.credentialReferences
            where !held.secretReferences.contains(reference) && credential(reference, in: id) == .loading {
            await readCredential(reference, in: id)
        }
    }

    private func readCredential(_ reference: SecretReference, in id: Request.ID) async {
        guard entries[id]?.saved.auth.requestAuth.secretReferences.contains(reference) == true else {
            return
        }
        let value = await secretStore.credential(reference)
        entries[id]?.credentials.record(value, for: reference)
        entries[id]?.discardCredentialsMatchingStore()
    }

    func revert(_ id: Request.ID) {
        if let saved = entries[id]?.saved {
            entries[id]?.draft = saved
        }
    }

    func keepRequests(_ ids: Set<Request.ID>) {
        if entries.keys.contains(where: { !ids.contains($0) }) {
            entries = entries.filter { ids.contains($0.key) }
        }
    }

}
