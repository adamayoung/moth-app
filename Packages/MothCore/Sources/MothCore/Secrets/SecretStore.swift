//  SecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

public protocol SecretStore {

    func save(_ value: String, for identifier: String) throws

    func value(for identifier: String) throws -> String?

    func removeValue(for identifier: String) throws

}
