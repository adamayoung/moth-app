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

    /// Takes the auth the draft read, and returns the references the write leaves unheld.
    typealias Save = @MainActor (Request.ID, RequestEdit, Auth) async throws -> Set<SecretReference>

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

        /// A sync never takes what was typed, but a body or auth nobody touched follows it, because a Save would
        /// otherwise put back what another Mac has replaced.
        mutating func moveSaved(to newSaved: RequestDraft) {
            if !isEdited {
                draft = newSaved
            } else {
                if draft.body.hasSameContent(as: saved.body) {
                    draft.body = newSaved.body
                }
                if draft.auth.hasSameContent(as: saved.auth) {
                    draft.auth = newSaved.auth
                }
            }
            saved = newSaved
        }

    }

    private var entries: [Request.ID: Entry] = [:]
    private var unreadable: Set<Request.ID> = []
    private let secretStore: any SecretStore
    private let saveEdit: Save
    @ObservationIgnored private var lastWrite: Task<Void, Never>?

    init(secretStore: any SecretStore, save: @escaping Save) {
        self.secretStore = secretStore
        self.saveEdit = save
    }

    convenience init(writer: StoreWriter, secretStore: any SecretStore) {
        self.init(secretStore: secretStore) { id, edit, held in
            try await writer.updateRequest(id, with: edit, replacing: held)
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
        await inOrder { await self.readCredential(reference, in: id) }
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
        await inOrder { await self.writeDraft(id) }
    }

    private func writeDraft(_ id: Request.ID) async -> Bool {
        guard !isUnreadable(id) else {
            return false
        }
        guard let entry = entries[id], entry.isEdited else {
            return true
        }
        let edit = entry.draft.edit
        let held = entry.saved.auth.requestAuth
        do {
            try await writeCredentials(of: entry.draft.auth, heldBy: held, in: id)
            let released = try await saveEdit(id, edit, held)
            await secretStore.remove(released)
            entries[id]?.credentials.forget(released)
        } catch {
            Logger.editor.error("Saving a request failed: \(String(describing: error), privacy: .private)")
            return false
        }
        await finishSave(of: edit, from: entry.draft, heldBy: held, in: id)
        return true
    }

    /// Values go first: a stray item is harmless, and a row referring to no value would lose it.
    private func writeCredentials(of auth: AuthDraft, heldBy held: Auth, in id: Request.ID) async throws {
        for write in auth.credentialWrites(heldBy: held) {
            try await secretStore.apply(write)
            entries[id]?.credentials.record(write.value, for: write.reference)
        }
    }

    private func finishSave(
        of edit: RequestEdit,
        from draft: RequestDraft,
        heldBy held: Auth,
        in id: Request.ID
    ) async {
        let saved = RequestDraft(edit)
        let isUnchanged = entries[id]?.draft.hasSameContent(as: draft) ?? false
        entries[id]?.saved = saved
        if isUnchanged {
            entries[id]?.draft = saved
        }
        entries[id]?.discardCredentialsMatchingStore()
        if
            let reference = saved.auth.credentialReference,
            !held.secretReferences.contains(reference),
            credential(reference, in: id) == .loading {
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

    /// Keychain calls finish in no set order, so a later Save could otherwise be overtaken by an earlier one, or a
    /// read could put back a value a Save has just replaced.
    private func inOrder<Value: Sendable>(_ work: @escaping () async -> Value) async -> Value {
        let previous = lastWrite
        let next = Task {
            await previous?.value
            return await work()
        }
        lastWrite = Task { _ = await next.value }
        return await next.value
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
