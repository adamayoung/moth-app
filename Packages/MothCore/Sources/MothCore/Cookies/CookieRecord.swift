//  CookieRecord.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// A record read from the store has an empty value: the value is in the Keychain under `valueIdentifier`.
nonisolated struct CookieRecord: Sendable, Hashable {

    let id: UUID
    var cookie: Cookie

    init(id: UUID = UUID(), cookie: Cookie) {
        self.id = id
        self.cookie = cookie
    }

    var valueIdentifier: String {
        Self.valueIdentifier(for: id)
    }

    static func valueIdentifier(for id: UUID) -> String {
        "cookie.\(id.uuidString)"
    }

}
