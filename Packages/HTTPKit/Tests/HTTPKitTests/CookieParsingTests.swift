//  CookieParsingTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

struct CookieParsingTests {

    private let now = Date()

    private func received(_ setCookie: String, from address: String) throws -> [Cookie] {
        try Cookie.received(in: ["Set-Cookie": setCookie], from: #require(URL(string: address)), at: now)
    }

    @Test("A cookie with no Domain is host-only, with the default path and no expiry")
    func hostOnlyCookie() throws {
        let cookie = try #require(received("sid=abc", from: "http://API.example.com/v1/users").first)

        #expect(cookie.name == "sid")
        #expect(cookie.value == "abc")
        #expect(cookie.domain == "api.example.com")
        #expect(cookie.isHostOnly)
        #expect(cookie.path == "/v1")
        #expect(cookie.expiresAt == nil)
        #expect(cookie.createdAt == now)
    }

    @Test("A Domain attribute makes a domain cookie, without its leading dot")
    func domainCookie() throws {
        let cookie = try #require(received("sid=abc; Domain=.Example.com; Path=/", from: "http://api.example.com/")
            .first)

        #expect(cookie.domain == "example.com")
        #expect(!cookie.isHostOnly)
        #expect(cookie.path == "/")
    }

    @Test("Secure and HttpOnly are kept")
    func flags() throws {
        let cookie = try #require(received("sid=abc; Secure; HttpOnly", from: "https://example.com/").first)

        #expect(cookie.isSecure)
        #expect(cookie.isHTTPOnly)
    }

    @Test("Max-Age and Expires set an expiry")
    func expiry() throws {
        let maxAge = try #require(received("a=1; Max-Age=60", from: "http://example.com/").first)
        let expires = try #require(received("a=1; Expires=Wed, 21 Oct 2015 07:28:00 GMT", from: "http://example.com/")
            .first)

        #expect(try #require(maxAge.expiresAt) > now)
        #expect(expires.expiresAt == Date(timeIntervalSince1970: 1_445_412_480))
    }

    @Test("URLSession's comma-joined Set-Cookie holds several cookies, an Expires date's comma included")
    func commaJoinedHeader() throws {
        let cookies = try received(
            "a=1; Expires=Wed, 21 Oct 2035 07:28:00 GMT, b=2; Path=/p",
            from: "http://example.com/"
        )

        #expect(cookies.map(\.name) == ["a", "b"])
        #expect(cookies.map(\.path) == ["/", "/p"])
    }

    @Test("A Set-Cookie header is found whatever the case of its name")
    func headerNameCase() throws {
        let cookies = try Cookie.received(
            in: ["set-cookie": "a=1"],
            from: #require(URL(string: "http://example.com/")),
            at: now
        )

        #expect(cookies.map(\.name) == ["a"])
    }

    @Test("A Domain the host isn't in is refused", arguments: ["other.com", ".com", "com", "ample.com"])
    func foreignDomainIsRefused(domain: String) throws {
        #expect(try received("a=1; Domain=\(domain)", from: "http://www.example.com/").isEmpty)
    }

    @Test("An IP address takes no Domain but its own, which is host-only")
    func ipAddressDomain() throws {
        let own = try #require(received("a=1; Domain=127.0.0.1", from: "http://127.0.0.1:8080/").first)

        #expect(own.domain == "127.0.0.1")
        #expect(own.isHostOnly)
        #expect(try received("a=1; Domain=0.0.1", from: "http://127.0.0.1:8080/").isEmpty)
    }

    @Test("A Path that doesn't start with a slash takes the default path")
    func relativePath() throws {
        let cookie = try #require(received("a=1; Path=relative", from: "http://example.com/x/y").first)

        #expect(cookie.path == "/x")
    }

    @Test("The default path is the request path up to its last slash", arguments: [
        ("http://example.com", "/"),
        ("http://example.com/", "/"),
        ("http://example.com/login", "/"),
        ("http://example.com/a/b/", "/a/b"),
        ("http://example.com/a/b/c", "/a/b")
    ])
    func defaultPath(address: String, path: String) throws {
        #expect(try received("a=1", from: address).first?.path == path)
    }

    @Test("A response with no Set-Cookie has no cookies")
    func noHeader() throws {
        let cookies = try Cookie.received(
            in: ["Content-Type": "text/plain"],
            from: #require(URL(string: "http://example.com/")),
            at: now
        )

        #expect(cookies.isEmpty)
    }

}
