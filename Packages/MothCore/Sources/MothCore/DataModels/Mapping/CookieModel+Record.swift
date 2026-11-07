//  CookieModel+Record.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit

nonisolated extension CookieModel {

    convenience init(_ record: CookieRecord, workspaceID: UUID) {
        self.init()
        id = record.id
        self.workspaceID = workspaceID
        valueIdentifier = record.valueIdentifier
        update(from: record.cookie)
    }

    var record: CookieRecord {
        CookieRecord(
            id: id,
            cookie: Cookie(
                name: name,
                value: "",
                domain: domain,
                isHostOnly: isHostOnly,
                path: path,
                expiresAt: expiresAt,
                isSecure: isSecure,
                isHTTPOnly: isHTTPOnly,
                createdAt: createdAt
            )
        )
    }

    /// Compares first, because an equal-value assignment still rewrites the row.
    func update(from cookie: Cookie) {
        var metadata = cookie
        metadata.value = ""
        guard record.cookie != metadata else {
            return
        }
        name = cookie.name
        domain = cookie.domain
        isHostOnly = cookie.isHostOnly
        path = cookie.path
        expiresAt = cookie.expiresAt
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
        createdAt = cookie.createdAt
    }

}
