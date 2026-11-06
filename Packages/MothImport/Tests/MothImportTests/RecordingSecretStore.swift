//  RecordingSecretStore.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore

actor RecordingSecretStore: SecretStore {

    enum Failure: Error {

        case refused

    }

    private(set) var values: [String: String] = [:]
    private let refusedValue: String?

    init(refusing refusedValue: String? = nil) {
        self.refusedValue = refusedValue
    }

    func save(_ value: String, for identifier: String) throws {
        if value == refusedValue {
            throw Failure.refused
        }
        values[identifier] = value
    }

    func value(for identifier: String) -> String? {
        values[identifier]
    }

    func removeValue(for identifier: String) {
        values[identifier] = nil
    }

}
