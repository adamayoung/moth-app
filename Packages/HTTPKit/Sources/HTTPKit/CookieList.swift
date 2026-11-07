//  CookieList.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public struct CookieChange: Sendable, Hashable {

    public var saved: [Cookie] = []
    public var removed: [Cookie] = []

    public var isEmpty: Bool {
        saved.isEmpty && removed.isEmpty
    }

}

/// RFC 6265 section 5.3's storage rules, as a value, so a persistent jar applies the same rules as one in memory.
public struct CookieList: Sendable, Hashable {

    public private(set) var cookies: [Cookie]

    public init(_ cookies: [Cookie] = []) {
        self.cookies = cookies
    }

    @discardableResult
    public mutating func receive(_ incoming: [Cookie], at now: Date) -> CookieChange {
        var change = CookieChange()
        for var cookie in incoming {
            let replaced = cookies.firstIndex { $0.identity == cookie.identity }.map { cookies.remove(at: $0) }
            if cookie.isExpired(at: now) {
                change.removed += replaced.map { [$0] } ?? []
                continue
            }
            cookie.createdAt = replaced?.createdAt ?? cookie.createdAt
            cookies.append(cookie)
            change.saved.append(cookie)
        }
        return change
    }

    /// Longer paths first, then older cookies, as RFC 6265 section 5.4 recommends.
    public func sending(to url: URL, at now: Date) -> [Cookie] {
        cookies
            .filter { $0.matches(url, at: now) }
            .sorted { ($0.path.count, $1.createdAt) > ($1.path.count, $0.createdAt) }
    }

    @discardableResult
    public mutating func removeExpired(at now: Date) -> [Cookie] {
        let expired = cookies.filter { $0.isExpired(at: now) }
        cookies.removeAll { $0.isExpired(at: now) }
        return expired
    }

    @discardableResult
    public mutating func remove(where shouldRemove: (Cookie) -> Bool) -> [Cookie] {
        let removed = cookies.filter(shouldRemove)
        cookies.removeAll(where: shouldRemove)
        return removed
    }

}
