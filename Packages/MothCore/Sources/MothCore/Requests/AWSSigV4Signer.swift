//  AWSSigV4Signer.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation

/// `path` and `query` are as they go on the wire: already percent-encoded once.
nonisolated struct AWSSigV4Signer: Sendable {

    struct Credentials: Sendable {

        let accessKey: String
        let secretKey: String
        let region: String
        let service: String

        var isS3: Bool {
            service == "s3"
        }

    }

    private static let algorithm = "AWS4-HMAC-SHA256"
    private static let unreservedBytes = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~".utf8)

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).hexadecimal
    }

    let method: String
    let path: String
    let query: String?
    let headers: [String: String]
    let payloadHash: String
    let date: Date
    let credentials: Credentials

    var canonicalRequest: String {
        [method, canonicalPath, canonicalQuery, canonicalHeaders, signedHeaders, payloadHash]
            .joined(separator: "\n")
    }

    var stringToSign: String {
        [Self.algorithm, timestamp, scope, Self.hash(wireBytes(of: canonicalRequest))].joined(separator: "\n")
    }

    var signature: String {
        Self.authenticate(stringToSign, with: signingKey).hexadecimal
    }

    var authorization: String {
        "\(Self.algorithm) Credential=\(credentials.accessKey)/\(scope), "
            + "SignedHeaders=\(signedHeaders), Signature=\(signature)"
    }

    private var timestamp: String {
        date.formatted(.awsSigV4Timestamp)
    }

    private var scope: String {
        "\(timestamp.prefix(8))/\(credentials.region)/\(credentials.service)/aws4_request"
    }

    private var signingKey: SymmetricKey {
        [timestamp.prefix(8).description, credentials.region, credentials.service, "aws4_request"]
            .reduce(SymmetricKey(data: Data("AWS4\(credentials.secretKey)".utf8))) { key, message in
                SymmetricKey(data: Self.authenticate(message, with: key))
            }
    }

    private var canonicalPath: String {
        credentials.isS3 ? s3Path : normalizedPath
    }

    /// S3 keys are literal, so `a//b` and `a/../b` name real objects, and S3 encodes only once.
    private var s3Path: String {
        guard !path.isEmpty else {
            return "/"
        }

        return path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { Self.reencoded($0) }
            .joined(separator: "/")
    }

    /// Every other service normalizes the path, then reads a wire path as text, which is AWS's double encoding.
    private var normalizedPath: String {
        var segments: [Substring] = []

        for segment in path.split(separator: "/") where segment != "." {
            if segment == ".." {
                _ = segments.popLast()
            } else {
                segments.append(segment)
            }
        }

        let trailingSlash = path.hasSuffix("/") && !segments.isEmpty ? "/" : ""
        return "/" + segments.map(\.description.percentEncoded).joined(separator: "/") + trailingSlash
    }

    private var canonicalQuery: String {
        (query ?? "")
            .split(separator: "&")
            .map { pair -> (name: String, value: String) in
                let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                return (Self.reencodedQueryText(parts[0]), Self.reencodedQueryText(parts.dropFirst().first ?? ""))
            }
            .sorted { ($0.name, $0.value) < ($1.name, $1.value) }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "&")
    }

    /// A server reads a literal `+` in a query as a space.
    private static func reencodedQueryText(_ text: Substring) -> String {
        reencoded(String(text).replacing("+", with: " "))
    }

    /// Works on bytes, because an escape need not be UTF-8, and text decoding would lose `%E9`.
    private static func reencoded(_ text: some StringProtocol) -> String {
        var bytes: [UInt8] = []
        var remainder = Substring(text).utf8

        while let byte = remainder.popFirst() {
            if byte == UInt8(ascii: "%"), let escaped = escapedByte(at: remainder) {
                bytes.append(escaped)
                remainder = remainder.dropFirst(2)
            } else {
                bytes.append(byte)
            }
        }

        return bytes.map { unreservedBytes.contains($0) ? String(UnicodeScalar($0)) : String(format: "%%%02X", $0) }
            .joined()
    }

    private static func escapedByte(at text: Substring.UTF8View) -> UInt8? {
        guard let digits = String(text.prefix(2)), digits.count == 2, digits.allSatisfy(\.isHexDigit) else {
            return nil
        }

        return UInt8(digits, radix: 16)
    }

    private var signedRows: [(name: String, value: String)] {
        headers
            .map { (name: $0.key.lowercased(), value: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private var canonicalHeaders: String {
        signedRows
            .map { "\($0.name):\($0.value.split { $0 == " " || $0 == "\t" }.joined(separator: " "))\n" }
            .joined()
    }

    private var signedHeaders: String {
        signedRows.map(\.name).joined(separator: ";")
    }

    /// URLSession writes a header value as Latin-1, and the server hashes the bytes it receives.
    private func wireBytes(of text: String) -> Data {
        text.data(using: .isoLatin1) ?? Data(text.utf8)
    }

    private static func authenticate(_ message: String, with key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key))
    }

}

nonisolated extension FormatStyle where Self == Date.ISO8601FormatStyle {

    static var awsSigV4Timestamp: Date.ISO8601FormatStyle {
        Date.ISO8601FormatStyle(
            dateSeparator: .omitted,
            dateTimeSeparator: .standard,
            timeSeparator: .omitted,
            timeZone: .gmt
        )
    }

}
