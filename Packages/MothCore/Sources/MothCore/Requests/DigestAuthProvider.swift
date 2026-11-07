//  DigestAuthProvider.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import Foundation

/// The first send carries no credentials, and each answer uses a fresh nonce count, because no nonce is reused.
public nonisolated struct DigestAuthProvider: AuthProvider {

    private static let nonceCount = "00000001"

    private let username: String
    private let password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func apply(to request: inout URLRequest) async throws {
        request.setValue(nil, forHTTPHeaderField: "Authorization")
    }

    func authorization(answering challenge: DigestChallenge, to request: URLRequest, cnonce: String) -> String {
        authorization(
            answering: challenge,
            method: request.httpMethod ?? "GET",
            uri: request.url.map(Self.requestTarget) ?? "/",
            cnonce: cnonce
        )
    }

    func authorization(answering challenge: DigestChallenge, method: String, uri: String, cnonce: String) -> String {
        let algorithm = challenge.algorithm
        var secret = algorithm.hash("\(username):\(challenge.realm):\(password)")
        if algorithm.isSession {
            secret = algorithm.hash("\(secret):\(challenge.nonce):\(cnonce)")
        }
        let requestHash = algorithm.hash("\(method):\(uri)")
        let response = algorithm.hash(
            [secret, challenge.nonce, Self.nonceCount, cnonce, "auth", requestHash].joined(separator: ":")
        )

        let fields = [
            usernameField,
            "realm=\(Self.quoted(challenge.realm))",
            "uri=\(Self.quoted(uri))",
            "algorithm=\(algorithm.rawValue)",
            "nonce=\(Self.quoted(challenge.nonce))",
            "nc=\(Self.nonceCount)",
            "cnonce=\(Self.quoted(cnonce))",
            "qop=auth",
            "response=\(Self.quoted(response))",
            challenge.opaque.map { "opaque=\(Self.quoted($0))" }
        ]
        return "Digest " + fields.compactMap(\.self).joined(separator: ", ")
    }

    /// RFC 7616 section 3.4.4: a username a quoted-string can't hold goes in `username*`, as RFC 5987 encodes it.
    private var usernameField: String {
        guard username.unicodeScalars.allSatisfy({ $0.isASCII && $0.value >= 0x20 && $0.value != 0x7F }) else {
            let encoded = username.addingPercentEncoding(withAllowedCharacters: Self.attributeCharacters) ?? ""
            return "username*=UTF-8''\(encoded)"
        }
        return "username=\(Self.quoted(username))"
    }

    private static let attributeCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!#$&+-.^_`|~"
    )

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacing("\\", with: "\\\\").replacing("\"", with: "\\\"") + "\""
    }

    /// What URLSession puts on the request line.
    static func requestTarget(of url: URL) -> String {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let path = components?.percentEncodedPath ?? ""
        let target = path.isEmpty ? "/" : path
        return components?.percentEncodedQuery.map { "\(target)?\($0)" } ?? target
    }

}
