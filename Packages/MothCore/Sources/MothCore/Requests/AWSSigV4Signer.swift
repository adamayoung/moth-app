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

    }

    static let s3 = "s3"

    private static let algorithm = "AWS4-HMAC-SHA256"

    static func hash(_ data: Data) -> String {
        hexadecimal(SHA256.hash(data: data))
    }

    let method: String
    let path: String
    let query: String?
    let headers: [String: String]
    let payload: Data
    let date: Date
    let credentials: Credentials

    var canonicalRequest: String {
        [method, canonicalPath, canonicalQuery, canonicalHeaders, signedHeaders, Self.hash(payload)]
            .joined(separator: "\n")
    }

    var stringToSign: String {
        [Self.algorithm, timestamp, scope, Self.hash(Data(canonicalRequest.utf8))].joined(separator: "\n")
    }

    var signature: String {
        Self.hexadecimal(Self.authenticate(stringToSign, with: signingKey))
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
        credentials.service == Self.s3 ? s3Path : normalizedPath
    }

    /// S3 keys are literal, so `a//b` and `a/../b` name real objects, and S3 encodes only once.
    private var s3Path: String {
        guard !path.isEmpty else {
            return "/"
        }

        return path
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { segment in (String(segment).removingPercentEncoding ?? String(segment)).percentEncoded }
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
                return (Self.canonicalQueryText(parts[0]), Self.canonicalQueryText(parts.dropFirst().first ?? ""))
            }
            .sorted { ($0.name, $0.value) < ($1.name, $1.value) }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "&")
    }

    /// A server reads a literal `+` in a query as a space.
    private static func canonicalQueryText(_ text: Substring) -> String {
        let spaced = String(text).replacing("+", with: " ")
        return (spaced.removingPercentEncoding ?? spaced).percentEncoded
    }

    private var signedRows: [(name: String, value: String)] {
        headers
            .map { (name: $0.key.lowercased(), value: $0.value) }
            .sorted { $0.name < $1.name }
    }

    private var canonicalHeaders: String {
        signedRows
            .map { "\($0.name):\($0.value.split(whereSeparator: \.isWhitespace).joined(separator: " "))\n" }
            .joined()
    }

    private var signedHeaders: String {
        signedRows.map(\.name).joined(separator: ";")
    }

    private static func authenticate(_ message: String, with key: SymmetricKey) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key))
    }

    private static func hexadecimal(_ bytes: some Sequence<UInt8>) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
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
