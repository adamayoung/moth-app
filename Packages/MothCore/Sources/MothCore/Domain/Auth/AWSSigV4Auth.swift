//  AWSSigV4Auth.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public nonisolated struct AWSSigV4Auth: Sendable, Hashable, Codable {

    public var accessKeyID: SecretReference
    public var secretAccessKey: SecretReference
    public var sessionToken: SecretReference?
    public var region: String
    public var service: String

    public init(
        accessKeyID: SecretReference,
        secretAccessKey: SecretReference,
        sessionToken: SecretReference? = nil,
        region: String,
        service: String
    ) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.sessionToken = sessionToken
        self.region = region
        self.service = service
    }

}
