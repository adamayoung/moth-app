//  CookieJar.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation

public protocol CookieJar: Sendable {

    func cookies(for url: URL) async -> [Cookie]

    /// `url` is the response's, whose scheme decides whether it may replace a Secure cookie.
    func receive(_ cookies: [Cookie], from url: URL) async

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

    public func receive(_ cookies: [Cookie], from url: URL) {
        list.receive(cookies, at: now(), overSecureScheme: url.isSecureScheme)
    }

}

public extension URL {

    var isSecureScheme: Bool {
        scheme?.lowercased() == "https"
    }

}
