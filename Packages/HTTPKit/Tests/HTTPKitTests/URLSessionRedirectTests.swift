//  URLSessionRedirectTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

/// Over real sockets, because only a real redirect runs URLSession's redirect delegate.
struct URLSessionRedirectTests {

    private static let hello = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"

    private let transport = URLSessionHTTPTransport(
        session: URLSession(configuration: URLSessionHTTPTransport.sessionConfiguration)
    )

    private static func redirect(to location: String) -> String {
        "HTTP/1.1 302 Found\r\nLocation: \(location)\r\nX-Hop: first\r\nContent-Length: 0\r\n\r\n"
    }

    private static func cookie(_ name: String, _ value: String, domain: String) -> Cookie {
        Cookie(
            name: name,
            value: value,
            domain: domain,
            isHostOnly: true,
            path: "/",
            expiresAt: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private static func withCredentials(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("m=0", forHTTPHeaderField: "Cookie")
        request.setValue("key", forHTTPHeaderField: "X-API-Key")
        request.setValue("kept", forHTTPHeaderField: "X-Custom")
        return request
    }

    @Test("With redirects off, the 3xx comes back with its status and headers, and its target is never asked")
    func notFollowed() async throws {
        let server = try await LoopbackServer(routes: ["/start": Self.redirect(to: "/final"), "/final": Self.hello])

        let response = try await transport.send(
            URLRequest(url: server.url(path: "/start")),
            cookies: nil,
            policy: SendPolicy(followsRedirects: false)
        )

        #expect(response.status == 302)
        #expect(response.value(forHeader: "Location") == "/final")
        #expect(response.value(forHeader: "X-Hop") == "first")
        #expect(server.request(to: "/final") == nil)
    }

    @Test("With redirects on, the final response comes back")
    func followed() async throws {
        let server = try await LoopbackServer(routes: ["/start": Self.redirect(to: "/final"), "/final": Self.hello])

        let response = try await transport.send(
            URLRequest(url: server.url(path: "/start")),
            cookies: nil,
            policy: SendPolicy(followsRedirects: true)
        )

        #expect(response.status == 200)
        #expect(response.body == Data("hello".utf8))
        #expect(try response.url == server.url(path: "/final"))
    }

    @Test("A redirect to another host carries neither Authorization nor a typed Cookie, on the wire")
    func anotherHostGetsNoCredentials() async throws {
        let target = try await LoopbackServer(routes: ["/final": Self.hello])
        let start = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: target.url(path: "/final", host: "localhost").absoluteString)
        ])

        let response = try await transport.send(Self.withCredentials(start.url(path: "/start")))

        #expect(response.status == 200)
        let first = try #require(start.request(to: "/start"))
        #expect(first.contains("\r\nAuthorization: Bearer secret\r\n"))
        #expect(first.contains("\r\nCookie: m=0\r\n"))
        let second = try #require(target.request(to: "/final"))
        #expect(!second.contains("Authorization:"))
        #expect(!second.contains("Cookie:"))
        #expect(second.contains("\r\nX-Custom: kept\r\n"))
    }

    @Test("Another port on the same host is another origin, so the credentials stay behind")
    func anotherPortGetsNoCredentials() async throws {
        let target = try await LoopbackServer(routes: ["/final": Self.hello])
        let start = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: target.url(path: "/final").absoluteString)
        ])

        _ = try await transport.send(Self.withCredentials(start.url(path: "/start")))

        let second = try #require(target.request(to: "/final"))
        #expect(!second.contains("Authorization:"))
        #expect(!second.contains("Cookie:"))
    }

    @Test("With a jar, another host gets its own cookies, and neither the typed Cookie nor the first host's")
    func anotherHostGetsItsOwnCookies() async throws {
        let target = try await LoopbackServer(routes: ["/final": Self.hello])
        let start = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: target.url(path: "/final", host: "localhost").absoluteString)
        ])
        let jar = InMemoryCookieJar([
            Self.cookie("a", "1", domain: "127.0.0.1"),
            Self.cookie("t", "2", domain: "localhost")
        ])

        _ = try await transport.send(Self.withCredentials(start.url(path: "/start")), cookies: jar)

        #expect(try #require(start.request(to: "/start")).contains("\r\nCookie: m=0; a=1\r\n"))
        #expect(try #require(target.request(to: "/final")).contains("\r\nCookie: t=2\r\n"))
    }

    @Test("A redirect on the same origin keeps the typed Cookie, and URLSession drops Authorization on any redirect")
    func sameOriginKeepsCredentials() async throws {
        let server = try await LoopbackServer(routes: ["/start": Self.redirect(to: "/final"), "/final": Self.hello])
        var policy = SendPolicy()
        policy.credentialHeaders.insert("x-api-key")

        _ = try await transport.send(Self.withCredentials(server.url(path: "/start")), cookies: nil, policy: policy)

        let second = try #require(server.request(to: "/final"))
        #expect(!second.contains("Authorization:"))
        #expect(second.contains("\r\nCookie: m=0\r\n"))
        #expect(second.contains("\r\nX-API-Key: key\r\n"))
    }

    @Test("A header the policy names as a credential stays behind on another origin too")
    func namedCredentialHeaderStaysBehind() async throws {
        let target = try await LoopbackServer(routes: ["/final": Self.hello])
        let start = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: target.url(path: "/final", host: "localhost").absoluteString)
        ])
        var policy = SendPolicy()
        policy.credentialHeaders.insert("x-api-key")

        _ = try await transport.send(Self.withCredentials(start.url(path: "/start")), cookies: nil, policy: policy)

        #expect(try #require(start.request(to: "/start")).contains("\r\nX-API-Key: key\r\n"))
        #expect(try !#require(target.request(to: "/final")).contains("X-API-Key:"))
    }

}
