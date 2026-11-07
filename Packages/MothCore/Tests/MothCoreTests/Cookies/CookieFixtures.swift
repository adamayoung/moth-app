//  CookieFixtures.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

nonisolated enum CookieFixtures {

    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    static func cookie(
        _ name: String = "sid",
        _ value: String = "abc",
        domain: String = "example.com",
        path: String = "/",
        expiresAt: Date? = nil
    ) -> Cookie {
        Cookie(
            name: name,
            value: value,
            domain: domain,
            isHostOnly: true,
            path: path,
            expiresAt: expiresAt,
            isSecure: true,
            isHTTPOnly: true,
            createdAt: now
        )
    }

    static var url: URL {
        get throws {
            try #require(URL(string: "https://example.com/"))
        }
    }

}

extension CookieJar {

    /// As from an HTTPS response, which may set any cookie.
    func receive(_ cookies: [Cookie]) async {
        await receive(cookies, from: URL(string: "https://example.com/") ?? URL(filePath: "/"))
    }

}
