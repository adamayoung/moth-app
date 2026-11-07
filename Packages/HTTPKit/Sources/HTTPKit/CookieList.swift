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

    /// A cookie is dated `now`. A plain HTTP response can't set a cookie that shares a Secure one's name, as RFC
    /// 6265bis
    /// section 5.7 says, and a cookie set again unchanged is left out of the change.
    @discardableResult
    public mutating func receive(_ incoming: [Cookie], at now: Date, overSecureScheme: Bool = true) -> CookieChange {
        var change = CookieChange()
        for var cookie in incoming {
            if !overSecureScheme, cookies.contains(where: { $0.isSecure && $0.sharesName(with: cookie) }) {
                continue
            }
            let index = cookies.firstIndex { $0.identity == cookie.identity }
            let replaced = index.map { cookies[$0] }
            cookie.createdAt = replaced?.createdAt ?? now
            switch (index, cookie.isExpired(at: now)) {
            case (let index?, true):
                cookies.remove(at: index)
                change.removed += replaced.map { [$0] } ?? []
            case (_, true):
                continue
            case (let index?, false):
                cookies[index] = cookie
                if cookie != replaced {
                    change.saved.append(cookie)
                }
            case (nil, false):
                cookies.append(cookie)
                change.saved.append(cookie)
            }
        }
        return change
    }

    public func sending(to url: URL, at now: Date) -> [Cookie] {
        cookies
            .filter { $0.matches(url, at: now) }
            .sorted { $0.sendsBefore($1) }
    }

    @discardableResult
    public mutating func removeExpired(at now: Date) -> [Cookie] {
        remove { $0.isExpired(at: now) }
    }

    @discardableResult
    public mutating func remove(where shouldRemove: (Cookie) -> Bool) -> [Cookie] {
        let removed = cookies.filter(shouldRemove)
        cookies.removeAll(where: shouldRemove)
        return removed
    }

}
