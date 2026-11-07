//  CookieMatchingTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct CookieMatchingTests {

    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func cookie(
        domain: String = "example.com",
        isHostOnly: Bool = true,
        path: String = "/",
        expiresAt: Date? = nil,
        isSecure: Bool = false
    ) -> Cookie {
        Cookie(
            name: "a",
            value: "1",
            domain: domain,
            isHostOnly: isHostOnly,
            path: path,
            expiresAt: expiresAt,
            isSecure: isSecure,
            createdAt: now
        )
    }

    private func matches(_ cookie: Cookie, _ address: String) throws -> Bool {
        try cookie.matches(#require(URL(string: address)), at: now)
    }

    @Test("A host-only cookie goes to its host alone, whatever the case or port")
    func hostOnly() throws {
        let hostOnly = cookie()

        #expect(try matches(hostOnly, "http://example.com/"))
        #expect(try matches(hostOnly, "http://EXAMPLE.com:8080/"))
        #expect(try !matches(hostOnly, "http://api.example.com/"))
        #expect(try !matches(hostOnly, "http://notexample.com/"))
    }

    @Test("A domain cookie goes to its domain and every subdomain")
    func domain() throws {
        let domain = cookie(isHostOnly: false)

        #expect(try matches(domain, "http://example.com/"))
        #expect(try matches(domain, "http://api.example.com/"))
        #expect(try matches(domain, "http://a.b.example.com/"))
        #expect(try !matches(domain, "http://notexample.com/"))
        #expect(try !matches(domain, "http://example.org/"))
    }

    @Test("A path matches itself and what lies below it, never a longer name", arguments: [
        ("/api", "/api", true),
        ("/api", "/api/users", true),
        ("/api/", "/api/users", true),
        ("/api", "/apis", false),
        ("/api", "/", false),
        ("/", "/anything", true),
        ("/api", "", false)
    ])
    func path(cookiePath: String, requestPath: String, expected: Bool) throws {
        #expect(try matches(cookie(path: cookiePath), "http://example.com\(requestPath)") == expected)
    }

    @Test("An empty request path is the root")
    func emptyPathIsRoot() throws {
        #expect(try matches(cookie(path: "/"), "http://example.com"))
    }

    @Test("Only HTTP and HTTPS carry cookies", arguments: [
        ("http", true), ("https", true), ("ws", false), ("ftp", false)
    ])
    func scheme(scheme: String, expected: Bool) throws {
        #expect(try matches(cookie(), "\(scheme)://example.com/") == expected)
    }

    @Test("A Secure cookie goes over HTTPS only")
    func secure() throws {
        let secure = cookie(isSecure: true)

        #expect(try matches(secure, "https://example.com/"))
        #expect(try !matches(secure, "http://example.com/"))
    }

    @Test("An expired cookie is never sent, and a session cookie never expires")
    func expiry() throws {
        #expect(try !matches(cookie(expiresAt: now), "http://example.com/"))
        #expect(try !matches(cookie(expiresAt: now.addingTimeInterval(-1)), "http://example.com/"))
        #expect(try matches(cookie(expiresAt: now.addingTimeInterval(1)), "http://example.com/"))
        #expect(try matches(cookie(expiresAt: nil), "http://example.com/"))
    }

}
