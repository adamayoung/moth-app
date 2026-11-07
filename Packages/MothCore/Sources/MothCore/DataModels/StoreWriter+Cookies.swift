//  StoreWriter+Cookies.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import SwiftData

extension StoreWriter {

    func cookieRecords(in workspaceID: UUID) throws -> [CookieRecord] {
        try read { context in
            try context.fetch(CookieModel.inWorkspace(workspaceID)).map(\.record)
        }
    }

    /// Writes the metadata only: the caller has already saved each value under its record's `valueIdentifier`.
    func saveCookies(_ records: [CookieRecord], in workspaceID: UUID) throws {
        guard !records.isEmpty else {
            return
        }
        try write { context in
            let existing = try context.fetch(CookieModel.withIDs(records.map(\.id)))
            let rows = Dictionary(existing.map { ($0.id, $0) }) { first, _ in first }
            for record in records {
                if let row = rows[record.id] {
                    row.update(from: record.cookie)
                } else {
                    context.insert(CookieModel(record, workspaceID: workspaceID))
                }
            }
        }
    }

    func removeCookies(_ ids: [UUID]) throws {
        guard !ids.isEmpty else {
            return
        }
        try write { context in
            try context.fetch(CookieModel.withIDs(ids)).forEach(context.delete)
        }
    }

    /// Returns the removed rows' value identifiers, for the caller to remove from the Keychain.
    func removeCookiesOfDeletedWorkspaces() throws -> [String] {
        try write { context in
            let workspaces = try Set(context.fetch(FetchDescriptor<WorkspaceModel>()).map(\.id))
            let orphans = try context.fetch(FetchDescriptor<CookieModel>()).filter {
                !workspaces.contains($0.workspaceID)
            }
            orphans.forEach(context.delete)
            return orphans.map(\.valueIdentifier)
        }
    }

}
