//  OAuth2SignInRequest.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import CryptoKit
import Foundation

/// RFC 7636, with the S256 method only.
nonisolated struct PKCE: Sendable, Hashable {

    let verifier: String

    init(verifier: String) {
        self.verifier = verifier
    }

    init(randomBytes: Data) {
        self.verifier = randomBytes.base64URLEncoded
    }

    var challenge: String {
        Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
    }

}

/// The authorization request of RFC 6749 section 4.1.1, and the callback that answers it.
nonisolated struct OAuth2SignInRequest: Sendable {

    let authorizationURL: String
    let clientID: String
    let callbackURL: String
    let scope: String
    let state: String
    let pkce: PKCE

    func url() throws -> URL {
        guard
            var components = URLComponents(string: authorizationURL),
            let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            throw OAuth2TokenError.invalidAuthorizationURL
        }

        let scopeField = scope.isEmpty ? [] : [("scope", scope)]
        let fields = [
            ("response_type", "code"),
            ("client_id", clientID),
            ("redirect_uri", callbackURL)
        ] + scopeField + [
            ("state", state),
            ("code_challenge", pkce.challenge),
            ("code_challenge_method", "S256")
        ]
        let query = fields.map { "\($0.percentEncoded)=\($1.percentEncoded)" }.joined(separator: "&")
        components.percentEncodedQuery = [components.percentEncodedQuery, query]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "&")
        guard let url = components.url else {
            throw OAuth2TokenError.invalidAuthorizationURL
        }
        return url
    }

    func callbackScheme() throws -> String {
        try Self.callbackScheme(of: callbackURL)
    }

    /// A web authentication session only catches a callback at a custom scheme, so `http` and `https` can't be one.
    static func callbackScheme(of callbackURL: String) throws -> String {
        guard
            let scheme = URL(string: callbackURL)?.scheme?.lowercased(),
            !["http", "https"].contains(scheme)
        else {
            throw OAuth2TokenError.callbackNotCustomScheme
        }
        return scheme
    }

    /// The provider's error comes first, because some providers leave `state` off an error.
    func code(from callback: URL) throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let error = value("error") {
            throw OAuth2TokenError.signInRefused(error: error, description: value("error_description"))
        }
        guard value("state") == state else {
            throw OAuth2TokenError.stateMismatch
        }
        guard let code = value("code"), !code.isEmpty else {
            throw OAuth2TokenError.noAuthorizationCode
        }
        return code
    }

}

nonisolated extension Data {

    var base64URLEncoded: String {
        base64EncodedString()
            .replacing("+", with: "-")
            .replacing("/", with: "_")
            .replacing("=", with: "")
    }

}
