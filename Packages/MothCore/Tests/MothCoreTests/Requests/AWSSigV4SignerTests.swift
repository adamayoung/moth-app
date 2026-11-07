//  AWSSigV4SignerTests.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation
@testable import MothCore
import Testing

struct AWSSigV4SignerTests {

    private func signer(
        path: String = "/",
        query: String? = nil,
        headers: [String: String] = [:],
        service: String = "service"
    ) -> AWSSigV4Signer {
        AWSSigV4Signer(
            method: "GET",
            path: path,
            query: query,
            headers: headers.merging(["Host": "example.amazonaws.com"]) { first, _ in first },
            payloadHash: AWSSigV4Signer.hash(Data()),
            date: Date(timeIntervalSince1970: 1_440_938_160),
            credentials: AWSSigV4Signer.Credentials(
                accessKey: "AKIDEXAMPLE",
                secretKey: "secret",
                region: "us-east-1",
                service: service
            )
        )
    }

    private func line(_ number: Int, of text: String) -> String {
        String(text.split(separator: "\n", omittingEmptySubsequences: false)[number])
    }

    @Test(
        "A query keeps escapes that aren't UTF-8, in uppercase hex",
        arguments: [("name=caf%E9", "name=caf%E9"), ("name=caf%e9", "name=caf%E9"), ("%FF=1", "%FF=1")]
    )
    func queryKeepsRawEscapes(query: String, expected: String) {
        #expect(line(2, of: signer(query: query).canonicalRequest) == expected)
    }

    @Test("An S3 key keeps escapes that aren't UTF-8, in uppercase hex")
    func s3PathKeepsRawEscapes() {
        #expect(line(1, of: signer(path: "/caf%e9.txt", service: "s3").canonicalRequest) == "/caf%E9.txt")
    }

    @Test("A stray percent sign is encoded, because it isn't an escape")
    func strayPercent() {
        #expect(line(2, of: signer(query: "a=100%").canonicalRequest) == "a=100%25")
    }

    @Test("Header text hashes as the Latin-1 URLSession sends")
    func headerHashesAsSent() throws {
        let signer = signer(headers: ["X-Title": "café"])

        let bytes = try #require(signer.canonicalRequest.data(using: .isoLatin1))
        let hash = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()

        #expect(line(3, of: signer.stringToSign) == hash)
    }

    @Test("Only spaces and tabs collapse in a header value, because a non-breaking space is sent as it is")
    func headerWhitespace() {
        let canonical = signer(headers: ["X-Value": " a  \t b\u{A0}c "]).canonicalRequest

        #expect(canonical.contains("x-value:a b\u{A0}c\n"))
    }

}
