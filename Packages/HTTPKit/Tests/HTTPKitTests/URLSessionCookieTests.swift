//  URLSessionCookieTests.swift
//  HTTPKit
//
//  Copyright © 2026 Adam Young.

import Foundation
import HTTPKit
import Testing

/// Over a real socket, with the live session configuration, so URLSession's own cookie storage can't stand in for
/// the jar.
struct URLSessionCookieTests {

    private static let hello = "HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello"
    private static let login = "HTTP/1.1 200 OK\r\nSet-Cookie: sid=abc; Path=/\r\nContent-Length: 0\r\n\r\n"

    private let transport = URLSessionHTTPTransport(
        session: URLSession(configuration: URLSessionHTTPTransport.sessionConfiguration)
    )

    private static func redirect(to location: String, setting cookie: String? = nil) -> String {
        let setCookie = cookie.map { "Set-Cookie: \($0)\r\n" } ?? ""
        return "HTTP/1.1 302 Found\r\nLocation: \(location)\r\n\(setCookie)Content-Length: 0\r\n\r\n"
    }

    private static func cookie(_ name: String, _ value: String, domain: String = "127.0.0.1") -> Cookie {
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

    @Test("The session configuration keeps URLSession's own cookie storage, cache and credentials out")
    func sessionConfiguration() {
        let configuration = URLSessionHTTPTransport.sessionConfiguration

        #expect(configuration.httpCookieStorage == nil)
        #expect(!configuration.httpShouldSetCookies)
        #expect(configuration.urlCache == nil)
        #expect(configuration.urlCredentialStorage == nil)
    }

    @Test("A response's cookie goes into the jar")
    func storesFromTheResponse() async throws {
        let server = try await LoopbackServer(routes: ["/login": Self.login])
        let jar = InMemoryCookieJar()

        _ = try await transport.send(URLRequest(url: server.url(path: "/login")), cookies: jar)

        #expect(await jar.cookies.map(\.name) == ["sid"])
        #expect(await jar.cookies.first?.domain == "127.0.0.1")
    }

    @Test("A redirect response's cookie goes into the jar, and with the redirected request")
    func storesFromARedirect() async throws {
        let server = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: "/final", setting: "sid=abc; Path=/"),
            "/final": Self.hello
        ])
        let jar = InMemoryCookieJar()

        let response = try await transport.send(URLRequest(url: server.url(path: "/start")), cookies: jar)

        #expect(response.status == 200)
        #expect(await jar.cookies.map(\.name) == ["sid"])
        #expect(try #require(server.request(to: "/final")).contains("\r\nCookie: sid=abc\r\n"))
    }

    @Test("A cookie the jar holds goes out on the wire with the next request")
    func sendsTheJarsCookies() async throws {
        let server = try await LoopbackServer(routes: ["/hello": Self.hello])
        let jar = InMemoryCookieJar([Self.cookie("a", "1"), Self.cookie("b", "2")])

        _ = try await transport.send(URLRequest(url: server.url(path: "/hello")), cookies: jar)

        #expect(try #require(server.request(to: "/hello")).contains("\r\nCookie: a=1; b=2\r\n"))
    }

    @Test("A manual Cookie header is kept, and the jar's cookies are joined to it")
    func joinsAManualHeader() async throws {
        let server = try await LoopbackServer(routes: ["/hello": Self.hello])
        let jar = InMemoryCookieJar([Self.cookie("a", "1")])
        var request = try URLRequest(url: server.url(path: "/hello"))
        request.setValue("m=0", forHTTPHeaderField: "Cookie")

        _ = try await transport.send(request, cookies: jar)

        #expect(try #require(server.request(to: "/hello")).contains("\r\nCookie: m=0; a=1\r\n"))
    }

    @Test("A manual cookie wins over the jar's cookie of the same name")
    func manualWins() async throws {
        let server = try await LoopbackServer(routes: ["/hello": Self.hello])
        let jar = InMemoryCookieJar([Self.cookie("a", "jar")])
        var request = try URLRequest(url: server.url(path: "/hello"))
        request.setValue("a=mine", forHTTPHeaderField: "Cookie")

        _ = try await transport.send(request, cookies: jar)

        #expect(try #require(server.request(to: "/hello")).contains("\r\nCookie: a=mine\r\n"))
    }

    @Test("The jar's cookies don't follow a redirect to another host")
    func jarCookiesStayOnTheirHost() async throws {
        let target = try await LoopbackServer(routes: ["/final": Self.hello])
        let start = try await LoopbackServer(routes: [
            "/start": Self.redirect(to: target.url(path: "/final", host: "localhost").absoluteString)
        ])
        let jar = InMemoryCookieJar([Self.cookie("a", "1")])

        let response = try await transport.send(URLRequest(url: start.url(path: "/start")), cookies: jar)

        #expect(response.status == 200)
        #expect(try #require(start.request(to: "/start")).contains("\r\nCookie: a=1\r\n"))
        #expect(try !#require(target.request(to: "/final")).contains("Cookie:"))
    }

    @Test("Without a jar, nothing is stored and a manual header goes as written")
    func withoutAJar() async throws {
        let server = try await LoopbackServer(routes: ["/login": Self.login])
        var request = try URLRequest(url: server.url(path: "/login"))
        request.setValue("m=0", forHTTPHeaderField: "Cookie")

        let response = try await transport.send(request)

        #expect(response.value(forHeader: "Set-Cookie") == "sid=abc; Path=/")
        #expect(try #require(server.request(to: "/login")).contains("\r\nCookie: m=0\r\n"))
    }

}
