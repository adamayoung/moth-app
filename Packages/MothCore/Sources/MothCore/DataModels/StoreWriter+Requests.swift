//  StoreWriter+Requests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

public extension StoreWriter {

    /// Every row with this id, because sync can duplicate one, and a twin left behind would bring the old fields back.
    /// Throws for a row this build can't read, which may hold fields the editor never showed. Returns the references
    /// this leaves unheld, for the caller to remove once the save has landed, because a `SecItem` call has no place in
    /// the synchronous write. `held` is the auth the caller read.
    @discardableResult
    func updateRequest(
        _ id: Request.ID,
        with edit: RequestEdit,
        replacing held: Auth
    ) throws -> Set<SecretReference> {
        try write { context in
            let rows = try context.fetch(RequestModel.withID(id))
            guard !rows.isEmpty else {
                return []
            }
            for row in rows {
                _ = try row.asDomain()
            }
            let released = try Self.credentials(releasedBy: rows, replacing: held, with: edit.auth, in: context)
            for row in rows {
                try row.apply(edit)
            }
            return released
        }
    }

}
