//  BasicAuth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct BasicAuth: Sendable, Hashable {

    public var username: String
    public var password: SecretReference

    public init(username: String, password: SecretReference) {
        self.username = username
        self.password = password
    }

}
