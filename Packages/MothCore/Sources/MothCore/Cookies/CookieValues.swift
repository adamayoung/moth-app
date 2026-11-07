//  CookieValues.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

nonisolated enum CookieValues {

    struct Removal {

        var ids: [UUID] = []
        var failure: any Error?

    }

    /// Tries every value, and names the rows whose value went, so a row is kept for each value that stays.
    static func remove(_ records: [CookieRecord], from secretStore: any SecretStore) async -> Removal {
        var removal = Removal()
        for record in records {
            do {
                try await secretStore.removeValue(for: record.valueIdentifier)
                removal.ids.append(record.id)
            } catch {
                removal.failure = removal.failure ?? error
            }
        }
        return removal
    }

}
