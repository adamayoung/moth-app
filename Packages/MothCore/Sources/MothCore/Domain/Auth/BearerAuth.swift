//  BearerAuth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct BearerAuth: Sendable, Hashable, Codable {

    public var token: SecretReference

    public init(token: SecretReference) {
        self.token = token
    }

}
