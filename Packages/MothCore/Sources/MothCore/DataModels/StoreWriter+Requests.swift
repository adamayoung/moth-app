//  StoreWriter+Requests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public extension StoreWriter {

    /// Every row with this id, because sync can duplicate one, and a twin left behind would bring the old fields back.
    /// Throws for a row this build can't read, which may hold fields the editor never showed. `base` is what the draft
    /// started from: a body or auth the draft didn't change stays as stored, because a sync may have replaced it. A
    /// changed
    /// auth is checked against `base`, and this returns the references it leaves unheld, for the caller to remove once
    /// the
    /// save has landed, because a `SecItem` call has no place in the synchronous write.
    @discardableResult
    func updateRequest(
        _ id: Request.ID,
        with edit: RequestEdit,
        from base: RequestEdit
    ) throws -> Set<SecretReference> {
        try write { context in
            let rows = try context.fetch(RequestModel.withID(id))
            guard !rows.isEmpty else {
                return []
            }
            for row in rows {
                _ = try row.asDomain()
            }
            let released = edit.auth == base.auth
                ? []
                : try Self.credentials(releasedBy: rows, replacing: base.auth, with: edit.auth, in: context)
            for row in rows {
                try row.apply(edit, from: base)
            }
            return released
        }
    }

}
