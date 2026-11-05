//  APIKeyAuth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct APIKeyAuth: Sendable, Hashable, Codable {

    public var name: String
    public var value: SecretReference
    public var location: APIKeyLocation

    public init(name: String, value: SecretReference, location: APIKeyLocation) {
        self.name = name
        self.value = value
        self.location = location
    }

}

public nonisolated enum APIKeyLocation: Sendable, Hashable, Codable {

    case header
    case query

}
