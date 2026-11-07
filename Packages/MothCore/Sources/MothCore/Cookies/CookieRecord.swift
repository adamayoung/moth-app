//  CookieRecord.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

/// A stored cookie: its row's identifier and the cookie. The value goes to the Keychain under `valueIdentifier`, and
/// a record read from the store has an empty one.
nonisolated struct CookieRecord: Sendable, Hashable {

    let id: UUID
    var cookie: Cookie

    init(id: UUID = UUID(), cookie: Cookie) {
        self.id = id
        self.cookie = cookie
    }

    var valueIdentifier: String {
        "cookie.\(id.uuidString)"
    }

}
