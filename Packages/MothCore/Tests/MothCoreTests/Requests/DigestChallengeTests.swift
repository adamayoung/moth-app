//  DigestChallengeTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

@testable import MothCore
import Testing

struct DigestChallengeTests {

    @Test("A Digest challenge after a Basic one in a header URLSession joined is found")
    func afterBasic() throws {
        let challenge = try #require(
            DigestChallenge.first(in: #"Basic realm="other", Digest realm="api", nonce="abc", qop="auth""#
            )
        )

        #expect(challenge.realm == "api")
        #expect(challenge.nonce == "abc")
        #expect(challenge.algorithm == .md5)
        #expect(challenge.opaque == nil)
    }

    @Test("A quoted value keeps its commas and escaped quotes")
    func quotedValues() throws {
        let challenge = try #require(
            DigestChallenge.first(in: #"Digest realm="a, \"b\"", nonce="n", qop="auth", opaque="o,p""#
            )
        )

        #expect(challenge.realm == #"a, "b""#)
        #expect(challenge.opaque == "o,p")
    }

    @Test("Scheme, parameter names and the algorithm are read whatever their case")
    func caseInsensitive() throws {
        let challenge = try #require(
            DigestChallenge.first(in: #"DIGEST Realm="api", NONCE="n", QOP="AUTH", Algorithm=sha-256-SESS"#
            )
        )

        #expect(challenge.algorithm == .sha256Session)
    }

    @Test("The first challenge Moth can answer wins, in the server's order")
    func firstSupported() throws {
        let challenge = try #require(DigestChallenge.first(in: """
        Digest realm="api", nonce="1", qop="auth-int", \
        Digest realm="api", nonce="2", qop="auth", algorithm=MD5, \
        Digest realm="api", nonce="3", qop="auth", algorithm=SHA-256
        """))

        #expect(challenge.nonce == "2")
    }

    @Test(
        "A challenge Moth can't answer is offered but not supported",
        arguments: [
            #"Digest realm="api", nonce="n", qop="auth-int""#,
            #"Digest realm="api", nonce="n", qop="auth", algorithm=SHA-512-256"#,
            #"Digest realm="api", nonce="n""#,
            #"Digest realm="api", qop="auth""#
        ]
    )
    func unsupported(header: String) {
        #expect(AuthChallenge.all(in: header).contains { $0.isScheme("Digest") })
        #expect(DigestChallenge.first(in: header) == nil)
    }

    @Test("An unquoted value keeps an = inside it, such as base64 padding")
    func unquotedValueWithEquals() throws {
        let challenge = try #require(DigestChallenge.first(in: #"Digest realm="api", nonce=MTYxNjQ=, qop="auth""#))

        #expect(challenge.nonce == "MTYxNjQ=")
    }

    @Test("A header with no Digest challenge offers none", arguments: [#"Basic realm="api""#, "Bearer", ""])
    func notOffered(header: String) {
        #expect(!AuthChallenge.all(in: header).contains { $0.isScheme("Digest") })
    }

}
