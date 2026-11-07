//  DigestAuthProviderTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation
@testable import MothCore
import Testing

struct DigestAuthProviderTests {

    private static let nonce = "7ypf/xlj9XXwfDPEoM4URrv/xwf94BcCAzFZH4GiTo0v"
    private static let cnonce = "f2/wE4q74E6zIJEtWaHKaf5wv/H5QzzpXusqGemxURZJ"
    private static let opaque = "FQhe/qaU925kfnzjCev0ciny7QMkPqMAFRtzCUYo5tdS"

    private let provider = DigestAuthProvider(username: "Mufasa", password: "Circle of Life")

    private static func challenge(algorithm: String) -> String {
        #"Digest realm="http-auth@example.org", qop="auth, auth-int", algorithm=\#(algorithm), "#
            + #"nonce="\#(nonce)", opaque="\#(opaque)""#
    }

    private func answer(_ header: String, method: String = "GET", uri: String = "/dir/index.html") throws -> String {
        let challenge = try #require(DigestChallenge.first(in: header))
        return provider.authorization(answering: challenge, method: method, uri: uri, cnonce: Self.cnonce)
    }

    @Test(
        "The answer matches RFC 7616 section 3.9.1",
        arguments: [
            ("MD5", "8ca523f5e9506fed4657c9700eebdbec"),
            ("SHA-256", "753927fa0e85d155564e2e272a28d1802ca10daf4496794697cf8db5856cb6c1")
        ]
    )
    func rfcVectors(algorithm: String, response: String) throws {
        let header = try answer(Self.challenge(algorithm: algorithm))

        #expect(header == #"Digest username="Mufasa", realm="http-auth@example.org", uri="/dir/index.html", "#
            + #"algorithm=\#(algorithm), nonce="\#(Self.nonce)", nc=00000001, cnonce="\#(Self.cnonce)", qop=auth, "#
            + #"response="\#(response)", opaque="\#(Self.opaque)""#)
    }

    @Test(
        "A -sess algorithm matches the RFC's formula on section 3.9.1's inputs, which the RFC publishes no answer for",
        arguments: [
            ("MD5-sess", "e783283f46242139c486a698fec7211d"),
            ("SHA-256-sess", "2fd51b3a77ad75bad6afad6003e818d767133c46d9e2749e7f5232ae1ea3efd7")
        ]
    )
    func sessionVectors(algorithm: String, response: String) throws {
        let header = try answer(Self.challenge(algorithm: algorithm))

        #expect(header.contains(#"response="\#(response)""#))
        #expect(header.contains("algorithm=\(algorithm),"))
    }

    @Test("The uri is the request-target as sent, with its query, and / for an empty path")
    func requestTarget() throws {
        let challenge = try #require(DigestChallenge.first(in: Self.challenge(algorithm: "MD5")))
        var request = try URLRequest(url: #require(URL(string: "https://example.com/a%20b?q=1&r=%2F")))
        request.httpMethod = "POST"
        let bare = try URLRequest(url: #require(URL(string: "https://example.com")))

        let answered = provider.authorization(answering: challenge, to: request, cnonce: Self.cnonce)

        #expect(answered.contains(#"uri="/a%20b?q=1&r=%2F""#))
        #expect(answered == provider.authorization(
            answering: challenge,
            method: "POST",
            uri: "/a%20b?q=1&r=%2F",
            cnonce: Self.cnonce
        ))
        #expect(provider.authorization(answering: challenge, to: bare, cnonce: Self.cnonce).contains(#"uri="/""#))
    }

    @Test("A username with a quote or backslash is escaped in its quoted-string")
    func escapedUsername() throws {
        let challenge = try #require(DigestChallenge.first(in: Self.challenge(algorithm: "MD5")))
        let provider = DigestAuthProvider(username: #"a"b\c"#, password: "p")

        let header = provider.authorization(answering: challenge, method: "GET", uri: "/", cnonce: "c")

        #expect(header.hasPrefix(#"Digest username="a\"b\\c", "#))
    }

    @Test("A username a quoted-string can't hold goes in username*, encoded as RFC 5987 says")
    func extendedUsername() throws {
        let challenge = try #require(DigestChallenge.first(in: Self.challenge(algorithm: "MD5")))
        let provider = DigestAuthProvider(username: "Jäsøn Doe", password: "p")

        let header = provider.authorization(answering: challenge, method: "GET", uri: "/", cnonce: "c")

        #expect(header.hasPrefix("Digest username*=UTF-8''J%C3%A4s%C3%B8n%20Doe, "))
    }

    @Test("The first send carries no Authorization header, even one typed as a header row")
    func firstSendHasNoAuthorization() async throws {
        var request = try URLRequest(url: #require(URL(string: "https://example.com")))
        request.setValue("Basic abc", forHTTPHeaderField: "Authorization")

        try await provider.apply(to: &request)

        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

}
