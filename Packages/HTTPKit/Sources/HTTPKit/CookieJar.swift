//  CookieJar.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public protocol CookieJar: Sendable {

    func cookies(for url: URL) async -> [Cookie]

    func receive(_ cookies: [Cookie]) async

}

public actor InMemoryCookieJar: CookieJar {

    private var list: CookieList
    private let now: @Sendable () -> Date

    public init(_ cookies: [Cookie] = [], now: @escaping @Sendable () -> Date = { Date() }) {
        self.list = CookieList(cookies)
        self.now = now
    }

    public var cookies: [Cookie] {
        list.cookies
    }

    public func cookies(for url: URL) -> [Cookie] {
        list.sending(to: url, at: now())
    }

    /// Dates each cookie by this jar's clock, which also decides expiry.
    public func receive(_ cookies: [Cookie]) {
        let now = now()
        list.receive(cookies.map { cookie in
            var cookie = cookie
            cookie.createdAt = now
            return cookie
        }, at: now)
    }

}
