//  InMemorySecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public final class InMemorySecretStore: SecretStore {

    private var values: [String: String] = [:]

    public init() {}

    public func save(_ value: String, for identifier: String) {
        values[identifier] = value
    }

    public func value(for identifier: String) -> String? {
        values[identifier]
    }

    public func removeValue(for identifier: String) {
        values[identifier] = nil
    }

}
