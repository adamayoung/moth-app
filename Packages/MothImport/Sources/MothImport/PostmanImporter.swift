//  PostmanImporter.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import PostmanKit

public struct PostmanImporter {

    public let secretStore: any SecretStore

    public init(secretStore: any SecretStore) {
        self.secretStore = secretStore
    }

    public func canImport(schema: String) -> Bool {
        PostmanSchema(rawValue: schema) != nil
    }

}
