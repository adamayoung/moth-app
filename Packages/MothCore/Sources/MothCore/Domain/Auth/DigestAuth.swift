//  DigestAuth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

/// Holds no realm or nonce, because the server's 401 challenge supplies them.
public nonisolated struct DigestAuth: Sendable, Hashable, Codable {

    public var username: String
    public var password: SecretReference

    public init(username: String, password: SecretReference) {
        self.username = username
        self.password = password
    }

}
