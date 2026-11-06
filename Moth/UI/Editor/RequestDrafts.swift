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

    typealias Save = @MainActor (Request.ID, RequestEdit) async throws -> Void

    private struct Entry {

        var saved: RequestDraft
        var draft: RequestDraft

        var isEdited: Bool {
            !draft.hasSameContent(as: saved)
        }

    }

    private var entries: [Request.ID: Entry] = [:]
    private var unreadable: Set<Request.ID> = []
    private let saveEdit: Save

    init(save: @escaping Save) {
        self.saveEdit = save
    }

    convenience init(writer: StoreWriter) {
        self.init { id, edit in
            try await writer.updateRequest(id, with: edit)
        }
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

    func isUnreadable(_ id: Request.ID) -> Bool {
        unreadable.contains(id)
    }

    func update(_ id: Request.ID, _ change: (inout RequestDraft) -> Void) {
        guard var entry = entries[id] else {
            return
        }
        change(&entry.draft)
        entries[id] = entry
    }

    /// Moves `saved` under an edited draft and leaves the draft alone, so a sync never takes what was typed, Revert
    /// goes
    /// to what is stored now, and the next Save wins.
    func savedRequestDidChange(_ request: Request) {
        unreadable.remove(request.id)
        let saved = RequestDraft(request)
        guard let entry = entries[request.id] else {
            entries[request.id] = Entry(saved: saved, draft: saved)
            return
        }
        guard !saved.hasSameContent(as: entry.saved) else {
            return
        }
        entries[request.id] = Entry(saved: saved, draft: entry.isEdited ? entry.draft : saved)
    }

    func savedRequestIsUnreadable(_ id: Request.ID) {
        unreadable.insert(id)
    }

    /// Returns whether the draft reached the store. Shows the stored form afterwards, so `?flag` reads `?flag=`, unless
    /// the person typed on during the save.
    func save(_ id: Request.ID) async -> Bool {
        guard let entry = entries[id], entry.isEdited else {
            return true
        }
        let edit = entry.draft.edit
        do {
            try await saveEdit(id, edit)
        } catch {
            Logger.editor.error("Saving a request failed: \(String(describing: error), privacy: .private)")
            return false
        }
        let saved = RequestDraft(edit)
        let isUnchanged = entries[id]?.draft.hasSameContent(as: entry.draft) ?? false
        entries[id]?.saved = saved
        if isUnchanged {
            entries[id]?.draft = saved
        }
        return true
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
