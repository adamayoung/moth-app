//  HoldingSecretStore.swift
//  MothTests
//
//  Copyright © 2026 Adam Young.

import MothCore

actor HoldingSecretStore: SecretStore {

    private(set) var values: [String: String] = [:]
    private var holdsNextSave = false
    private var heldSave: CheckedContinuation<Void, Never>?

    var isHoldingASave: Bool {
        heldSave != nil
    }

    func holdNextSave() {
        holdsNextSave = true
    }

    func finishHeldSave() {
        heldSave?.resume()
        heldSave = nil
    }

    func save(_ value: String, for identifier: String) async {
        if holdsNextSave {
            holdsNextSave = false
            await withCheckedContinuation { heldSave = $0 }
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
