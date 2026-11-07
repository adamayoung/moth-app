//  ControlledSecretStore.swift
//  MothCore
//
//  Copyright © 2026 Adam Young.

import MothCore

/// Keeps values in memory, and can hold a save, fail reads, or fail some removals, so a test can drive the jar's
/// failure and interleaving paths.
actor ControlledSecretStore: SecretStore {

    struct Failure: Error {}

    private var values: [String: String] = [:]
    private var failsReads = false
    private var failsSaves = false
    private var removalsToFail = 0
    private var holdsSaves = false
    private var heldSave: CheckedContinuation<Void, Never>?
    private let saveArrivals: AsyncStream<Void>
    private let saveArrival: AsyncStream<Void>.Continuation

    init() {
        (self.saveArrivals, self.saveArrival) = AsyncStream.makeStream()
    }

    var identifiers: Set<String> {
        Set(values.keys)
    }

    func failReads(_ fails: Bool) {
        failsReads = fails
    }

    func failSaves(_ fails: Bool) {
        failsSaves = fails
    }

    func failRemovals(_ count: Int) {
        removalsToFail = count
    }

    func holdNextSave() {
        holdsSaves = true
    }

    func waitForHeldSave() async {
        for await _ in saveArrivals {
            return
        }
    }

    func releaseSave() {
        heldSave?.resume()
        heldSave = nil
    }

    func save(_ value: String, for identifier: String) async throws {
        if failsSaves {
            throw Failure()
        }
        if holdsSaves {
            holdsSaves = false
            saveArrival.yield()
            await withCheckedContinuation { heldSave = $0 }
        }
        values[identifier] = value
    }

    func value(for identifier: String) throws -> String? {
        if failsReads {
            throw Failure()
        }
        return values[identifier]
    }

    func removeValue(for identifier: String) throws {
        if removalsToFail > 0 {
            removalsToFail -= 1
            throw Failure()
        }
        values[identifier] = nil
    }

}
